# Supplemental configuration for the upstream himmelblau NixOS module.
# The upstream module (inputs.himmelblau.nixosModules.himmelblau) provides:
#   himmelblau.conf generation, NSS, PAM (account/auth/session), systemd
#   services (himmelblaud + himmelblaud-tasks + user-scope broker), Chromium
#   native-messaging-host manifests, D-Bus broker service activation, and the
#   typed options under services.himmelblau.settings (auto-generated from
#   docs-xml).
# This module adds what the upstream still misses for our setup.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.himmelblau;
  system = pkgs.stdenv.hostPlatform.system;
  upstreamPackage = inputs.himmelblau.packages.${system}.himmelblau;
  # Upstream nix/packages/himmelblau.nix hardcodes version = "3.0.0" across all
  # 3.x releases; read the real version from the workspace Cargo.toml instead.
  upstreamVersion =
    (builtins.fromTOML
      (builtins.readFile "${inputs.himmelblau}/Cargo.toml")).workspace.package.version;

  # HSM PIN initialization — mirrors upstream
  # src/daemon/scripts/himmelblau-init-hsm-pin (3.1.6) which:
  #   - uses /var/lib/private/himmelblaud/hsm-pin-nopcr.enc (no PCR binding)
  #     so Secure Boot certificate updates do not invalidate the credential
  #   - migrates from the legacy plaintext /var/lib/private/himmelblaud/hsm-pin
  #     AND the legacy PCR-bound /var/lib/private/himmelblaud/hsm-pin.enc
  #   - self-provisions the TPM2 SRK at 0x81000001 when systemd-tpm2-setup
  #     was skipped (e.g. systems not booting via measured UKI).
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
    LEGACY1=/var/lib/private/himmelblaud/hsm-pin.enc
    CRED=/var/lib/private/himmelblaud/hsm-pin-nopcr.enc
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

    if [ -f "$CRED" ]; then
      if [ -f "$LEGACY" ]; then
        echo "Encrypted credential exists, removing legacy hsm-pin file"
        rm -f "$LEGACY"
      fi
      if [ -f "$LEGACY1" ]; then
        echo "Encrypted credential exists, removing legacy PCR-bound hsm-pin.enc"
        rm -f "$LEGACY1"
      fi
      if ([ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]) && srk_is_provisioned; then
        if HSM_PIN=$(${systemd-creds} decrypt --name=hsm-pin "$CRED" - 2>/dev/null); then
          CRED_TMP="''${CRED}.tmp"
          if printf '%s' "$HSM_PIN" | ${systemd-creds} encrypt \
                  --name=hsm-pin --with-key=host+tpm2 --tpm2-pcrs= \
                  --tpm2-device=auto - "$CRED_TMP" 2>/dev/null; then
            mv -f "$CRED_TMP" "$CRED"
            echo "HSM PIN credential upgraded to TPM-bound encryption (no PCR)"
          else
            rm -f "$CRED_TMP" 2>/dev/null || true
            echo "WARNING: Re-encryption to TPM-bound key failed. Keeping existing credential."
          fi
        fi
      fi
      echo "HSM PIN credential already exists, skipping initialization"
      exit 0
    fi

    # Generate new or migrate existing PIN.
    if [ -f "$LEGACY" ]; then
      echo "Migrating existing plaintext HSM-PIN to encrypted credential"
      HSM_PIN=$(cat "$LEGACY")
    elif [ -f "$LEGACY1" ]; then
      echo "Migrating existing PCR-bound HSM-PIN to no-PCR encryption"
      HSM_PIN=$(${systemd-creds} decrypt --name=hsm-pin "$LEGACY1")
    else
      echo "Generating new HSM-PIN"
      HSM_PIN=$(gen_pin_hex)
    fi

    if ([ -e /dev/tpmrm0 ] || [ -e /dev/tpm0 ]) && srk_is_provisioned; then
      KEY_ARG="--with-key=host+tpm2 --tpm2-pcrs="
    else
      echo "WARNING: TPM not available or SRK not provisioned. Using host key only."
      KEY_ARG="--with-key=auto --tpm2-pcrs="
    fi

    if printf '%s' "$HSM_PIN" | ${systemd-creds} encrypt --name=hsm-pin $KEY_ARG \
            --tpm2-device=auto - "$CRED"; then
      echo "HSM PIN credential created successfully"
      rm -f "$LEGACY" 2>/dev/null || true
      rm -f "$LEGACY1" 2>/dev/null || true
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
    # Upstream nix/packages/himmelblau.nix does not enable the `tpm` cargo
    # feature for himmelblau_unix_common, so the daemon falls back to a
    # software HSM even with TPM hardware available. Force-enable it and
    # add tpm2-tss so the resulting binary can talk to /dev/tpmrm0.
    # Also override the hardcoded "3.0.0" upstream sets in nix/packages.
    services.himmelblau.package = lib.mkForce (upstreamPackage.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.tpm2-tss ];
      cargoBuildFeatures = "himmelblau_unix_common/tpm";
      version = upstreamVersion;
      name = "${old.pname}-${upstreamVersion}";
      __intentionallyOverridingVersion = true;
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

    # Upstream nixosModules.himmelblau only wires pam_himmelblau into
    # account/auth/session — the password stack is missing, so `passwd`
    # cannot update the Hello PIN. Add it for every configured pamService
    # (matches upstream pam_himmelblau.8 recommendation:
    # `password sufficient pam_himmelblau.so ignore_unknown_user`).
    security.pam.services = let
      pamServiceNames = cfg.pamServices
        ++ lib.optional config.security.sudo.enable "sudo"
        ++ lib.optional config.security.doas.enable "doas"
        ++ lib.optional config.services.sshd.enable "sshd";
      passwordRule = service: {
        rules.password.himmelblau = {
          order = config.security.pam.services.${service}.rules.password.unix.order - 10;
          control = "sufficient";
          modulePath = "${cfg.package}/lib/libpam_himmelblau.so";
          settings.ignore_unknown_user = true;
          settings.debug = cfg.debugFlag;
        };
      };
    in lib.genAttrs pamServiceNames passwordRule;

    # User map file generation
    environment.etc = lib.mkIf (cfg.userMap != { }) {
      "himmelblau/user-map".text = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (local: upn: "${local}:${upn}") cfg.userMap);
    };

    # Contribute the himmelblau package as a Native Messaging host source
    # for the system-level zen-browser wrapped by modules/zen-browser. The
    # home-level zen built in home/default.nix is wired separately through
    # home-manager's `programs.firefox.nativeMessagingHosts`. Upstream's
    # nixosModules.himmelblau only wires `programs.firefox`, so this hook
    # is still required.
    programs.zen-browser.nativeMessagingHosts.packages = [ cfg.package ];

    # HSM PIN initialization — encrypts hsm-pin with TPM via systemd-creds.
    # Only runs if the encrypted credential does not yet exist (matching upstream).
    systemd.services.himmelblau-hsm-pin-init = {
      description = "Himmelblau HSM PIN Initialization";
      wantedBy = [ "multi-user.target" ];
      before = [ "himmelblaud.service" ];
      after = [ "systemd-tpm2-setup.service" ];
      unitConfig = {
        ConditionPathExists = "!/var/lib/private/himmelblaud/hsm-pin-nopcr.enc";
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
        LoadCredentialEncrypted = "hsm-pin:/var/lib/private/himmelblaud/hsm-pin-nopcr.enc";
      };
      # Tell himmelblaud to read the HSM PIN from systemd's credential store.
      environment = {
        HIMMELBLAU_HSM_PIN_PATH = "/run/credentials/himmelblaud.service/hsm-pin";
      };
    };

    # NetworkManager dispatcher hook — workaround for himmelblau-idm/himmelblau#1206
    # (resume/boot deadlock). Upstream ships
    # platform/common/NetworkManager/dispatcher.d/99-himmelblau-restart-on-down
    # which restarts himmelblaud whenever a physical interface goes down, so the
    # daemon does not keep a stale HTTP connection pool that hangs the socket on
    # the next auth (observed: Wi-Fi reconnect -> swaylock unlock ->
    # login.microsoftonline.com Connect TimedOut -> socket hang). The script is
    # only installed via the deb/rpm packaging (/usr/lib/NetworkManager/
    # dispatcher.d/), so on NixOS it must be wired explicitly. The dispatcher
    # PATH already provides systemctl, grep and logger. type = "basic" matches
    # the upstream install location (receives the "down" action).
    networking.networkmanager.dispatcherScripts = [{
      source = "${inputs.himmelblau}/platform/common/NetworkManager/dispatcher.d/99-himmelblau-restart-on-down";
      type = "basic";
    }];

    systemd.services.himmelblaud-tasks.serviceConfig = {
      RestartSec = "1s";
      # IPv4 + Unix only — himmelblaud_tasks fails on IPv6 with
      # "federation provider not set" errors before falling back to IPv4.
      RestrictAddressFamilies = lib.mkForce "AF_INET AF_UNIX";
      # Upstream omits /var/cache/himmelblau-policies, which is required
      # whenever apply_policy = true.
      ReadWritePaths = lib.mkForce
        "/home /var/run/himmelblaud /tmp /etc/krb5.conf.d /etc /var/lib /var/cache/nss-himmelblau /var/cache/himmelblau-policies";
      # Upstream nixosModule sets no CapabilityBoundingSet, whereas the
      # cargo-deb/rpm generator drops these caps. Apply the same set so
      # tasks can chown user dirs and switch UIDs for home creation.
      CapabilityBoundingSet =
        "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_SETUID CAP_SETGID";
    };
  };
}
