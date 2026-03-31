# Supplemental configuration for the upstream himmelblau NixOS module.
# The upstream module (inputs.himmelblau.nixosModules.himmelblau) provides:
#   - himmelblau.conf generation, NSS, PAM, systemd services, D-Bus, krb5, tmpfiles
# This module adds settings the upstream doesn't cover.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.himmelblau;
  system = pkgs.stdenv.hostPlatform.system;
  upstreamPackage = inputs.himmelblau.packages.${system}.himmelblau;

  # HSM PIN initialization script — encrypts the HSM PIN with systemd-creds
  # using TPM2 binding (host+tpm2) so that key material is bound to this machine's TPM.
  # Ported from upstream src/daemon/scripts/himmelblau-init-hsm-pin.
  initHsmPinScript = let
    openssl = "${pkgs.openssl}/bin/openssl";
    tpm2_getcap = "${pkgs.tpm2-tools}/bin/tpm2_getcap";
    tpm2_createprimary = "${pkgs.tpm2-tools}/bin/tpm2_createprimary";
    tpm2_evictcontrol = "${pkgs.tpm2-tools}/bin/tpm2_evictcontrol";
    systemd-creds = "${config.systemd.package}/bin/systemd-creds";
    srkHandle = "0x81000001";
  in pkgs.writeShellScript "himmelblau-init-hsm-pin" ''
    set -e

    LEGACY=/var/lib/private/himmelblaud/hsm-pin
    CRED=/var/lib/private/himmelblaud/hsm-pin.enc
    SRK_HANDLE=${srkHandle}

    gen_pin_hex() {
      ${openssl} rand -hex 24 | tr -d '\n'
    }

    srk_is_provisioned() {
      ${tpm2_getcap} handles-persistent 2>/dev/null | grep -q "$SRK_HANDLE"
    }

    provision_srk() {
      CTX=$(mktemp /tmp/himmelblau-srk.XXXXXX.ctx)
      trap 'rm -f "$CTX"' EXIT

      if ${tpm2_createprimary} \
              -C o -G ecc256:aes128cfb \
              -a "DECRYPT|FIXEDPARENT|FIXEDTPM|NODA|RESTRICTED|SENSITIVEDATAORIGIN|USERWITHAUTH" \
              -c "$CTX" >/dev/null 2>&1; then
        echo "SRK: created ECC P-256 primary key"
      elif ${tpm2_createprimary} \
              -C o -G rsa2048:aes128cfb \
              -a "DECRYPT|FIXEDPARENT|FIXEDTPM|NODA|RESTRICTED|SENSITIVEDATAORIGIN|USERWITHAUTH" \
              -c "$CTX" >/dev/null 2>&1; then
        echo "SRK: ECC not supported, created RSA-2048 primary key"
      else
        echo "WARNING: Failed to create TPM2 primary key for SRK provisioning."
        rm -f "$CTX"; trap - EXIT; return 1
      fi

      if ${tpm2_evictcontrol} -C o -c "$CTX" "$SRK_HANDLE" >/dev/null 2>&1; then
        echo "SRK provisioned at $SRK_HANDLE"
      else
        echo "WARNING: Failed to persist SRK at $SRK_HANDLE."
        rm -f "$CTX"; trap - EXIT; return 1
      fi

      rm -f "$CTX"; trap - EXIT; return 0
    }

    mkdir -p /var/lib/private/himmelblaud
    chmod 700 /var/lib/private/himmelblaud

    # Provision SRK if TPM is present but SRK is missing
    if [ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]; then
      if ! srk_is_provisioned; then
        echo "TPM present but SRK not provisioned — attempting self-provisioning..."
        if provision_srk; then
          echo "SRK self-provisioning succeeded"
        else
          echo "WARNING: SRK self-provisioning failed. HSM PIN will not be TPM-bound."
        fi
      fi
    fi

    # If encrypted credential already exists, try to upgrade to TPM-bound
    if [ -f "$CRED" ]; then
      if [ -f "$LEGACY" ]; then
        echo "Encrypted credential exists, removing legacy hsm-pin file"
        rm -f "$LEGACY"
      fi
      if ([ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]) && srk_is_provisioned; then
        if HSM_PIN=$(${systemd-creds} decrypt --name=hsm-pin "$CRED" - 2>/dev/null); then
          CRED_TMP="''${CRED}.tmp"
          if printf '%s' "$HSM_PIN" | ${systemd-creds} encrypt \
                  --name=hsm-pin --with-key=host+tpm2 --tpm2-device=auto \
                  - "$CRED_TMP" 2>/dev/null; then
            mv -f "$CRED_TMP" "$CRED"
            echo "HSM PIN credential upgraded to TPM-bound encryption"
          else
            rm -f "$CRED_TMP" 2>/dev/null || true
            echo "WARNING: Re-encryption to TPM-bound key failed. Keeping existing credential."
          fi
        fi
      fi
      echo "HSM PIN credential already exists, skipping initialization"
      exit 0
    fi

    # Generate new or migrate existing PIN
    if [ -f "$LEGACY" ]; then
      echo "Migrating existing HSM-PIN to encrypted credential"
      HSM_PIN=$(cat "$LEGACY")
    else
      echo "Generating new HSM-PIN"
      HSM_PIN=$(gen_pin_hex)
    fi

    # Choose strongest key binding available
    if ([ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]) && srk_is_provisioned; then
      KEY_ARG="--with-key=host+tpm2"
    else
      echo "WARNING: TPM not available or SRK not provisioned. Using host key only."
      KEY_ARG="--with-key=auto"
    fi

    if printf '%s' "$HSM_PIN" | ${systemd-creds} encrypt --name=hsm-pin $KEY_ARG \
            --tpm2-device=auto - "$CRED"; then
      echo "HSM PIN credential created successfully"
      rm -f "$LEGACY" 2>/dev/null || true
      exit 0
    else
      echo "ERROR: Failed to create HSM PIN credential"
      exit 1
    fi
  '';
in {
  options.services.himmelblau = {
    userMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description =
        "Mapping of local usernames to UPNs for Local User Mapping feature";
      example = { katsuma = "katsuma@example.onmicrosoft.com"; };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable hardware TPM support (cargo feature "tpm" in himmelblau_unix_common)
    services.himmelblau.package = lib.mkForce (upstreamPackage.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.tpm2-tss ];
      # overrideAttrs cannot re-derive cargoBuildFeatures from buildFeatures,
      # so set the env var that the cargo build hook actually reads.
      cargoBuildFeatures = "himmelblau_unix_common/tpm";
    }));

    # TPM2 support for HSM binding (abrmd NOT needed - direct /dev/tpmrm0 access)
    security.tpm2 = {
      enable = true;
      abrmd.enable = false;
    };

    # Required for apply_policy = true
    systemd.tmpfiles.rules = [
      "d /var/cache/himmelblau-policies 0600 root root -"
    ];

    # User map file generation
    environment.etc = lib.mkIf (cfg.userMap != { }) {
      "himmelblau/user-map".text = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (local: upn: "${local}:${upn}") cfg.userMap);
    };

    # HSM PIN initialization — encrypts hsm-pin with TPM via systemd-creds
    # Only runs if the encrypted credential does not yet exist (matching upstream).
    systemd.services.himmelblau-hsm-pin-init = {
      description = "Himmelblau HSM PIN Initialization";
      wantedBy = [ "multi-user.target" ];
      before = [ "himmelblaud.service" ];
      after = [ "systemd-tpm2-setup.service" ];
      unitConfig = {
        ConditionPathExists = "!/var/lib/private/himmelblaud/hsm-pin.enc";
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = initHsmPinScript;
        RemainAfterExit = true;
      };
    };

    # Systemd service hardening not covered by upstream module
    systemd.services.himmelblaud = {
      wants = [ "himmelblau-hsm-pin-init.service" ];
      after = [ "himmelblau-hsm-pin-init.service" ];
      serviceConfig = {
        # PRT preservation across service restarts
        FileDescriptorStoreMax = 10;
        # TPM access via tss group
        SupplementaryGroups = [ "tss" ];
        CacheDirectoryMode = "0700";
        StateDirectoryMode = "0700";
        # Pass the encrypted HSM PIN to himmelblaud via systemd credentials.
        # systemd decrypts it (using TPM if bound) and exposes at
        # /run/credentials/himmelblaud.service/hsm-pin.
        # %d specifier doesn't expand in Environment=, so we use
        # ExecStartPre to set it via the CREDENTIALS_DIRECTORY env var
        # that systemd provides automatically.
        LoadCredentialEncrypted = "hsm-pin:/var/lib/private/himmelblaud/hsm-pin.enc";
      };
      # Tell himmelblaud to read the HSM PIN from systemd's credential store.
      # CREDENTIALS_DIRECTORY is set by systemd when LoadCredential* is used.
      environment = {
        HIMMELBLAU_HSM_PIN_PATH = "/run/credentials/himmelblaud.service/hsm-pin";
      };
    };

    systemd.services.himmelblaud-tasks.serviceConfig = {
      RestartSec = "1s";
      # IPv4 + Unix only — himmelblaud_tasks fails on IPv6 with
      # "federation provider not set" errors before falling back to IPv4
      RestrictAddressFamilies = lib.mkForce "AF_INET AF_UNIX";
      ReadWritePaths = lib.mkForce
        "/home /var/run/himmelblaud /tmp /etc/krb5.conf.d /etc /var/lib /var/cache/nss-himmelblau /var/cache/himmelblau-policies";
      CapabilityBoundingSet =
        "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH";
    };
  };
}
