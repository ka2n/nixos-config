# Supplemental configuration for the upstream himmelblau NixOS module.
# The upstream module (inputs.himmelblau.nixosModules.himmelblau) provides:
#   - himmelblau.conf generation, NSS, PAM, systemd services, D-Bus, krb5, tmpfiles
# This module adds settings the upstream doesn't cover.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.himmelblau;
  system = pkgs.stdenv.hostPlatform.system;
  upstreamPackage = inputs.himmelblau.packages.${system}.himmelblau;
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

    # Systemd service hardening not covered by upstream module
    systemd.services.himmelblaud.serviceConfig = {
      # PRT preservation across service restarts
      FileDescriptorStoreMax = 10;
      # TPM access via tss group
      SupplementaryGroups = [ "tss" ];
      CacheDirectoryMode = "0700";
      StateDirectoryMode = "0700";
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
