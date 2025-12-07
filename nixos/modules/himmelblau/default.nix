{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.azure-entra;
  azureConfig = import ../../private/azure.nix;
  himmelblauPkg = pkgs.callPackage ./package.nix {
    himmelblauSrc = inputs.himmelblau;
  };
in
{
  options.services.azure-entra = {
    enable = lib.mkEnableOption "Azure Entra ID authentication via Himmelblau";

    package = lib.mkOption {
      type = lib.types.package;
      default = himmelblauPkg;
      description = "Himmelblau package to use";
    };


    debugFlag = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to pass the debug (-d) flag to the himmelblaud binary";
    };

    mfaSshWorkaroundFlag = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to add mfa_poll_prompt option to PAM module for OpenSSH Bug 2876 workaround";
    };

    pamServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "passwd" "login" ];
      description = "Which PAM services to add the himmelblau module to";
    };

    browserSso = {
      chrome = lib.mkEnableOption "Chrome native messaging host for Entra SSO";
      chromium = lib.mkEnableOption "Chromium native messaging host for Entra SSO";
      firefox = lib.mkEnableOption "Firefox native messaging host for Entra SSO";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable TPM2 support for HSM binding
    # Note: abrmd is NOT needed - himmelblau accesses /dev/tpmrm0 directly
    security.tpm2 = {
      enable = true;
      abrmd.enable = false;
    };

    # Create required directories via tmpfiles (same as Debian package)
    systemd.tmpfiles.rules = [
      "d /var/cache/himmelblau-policies 0600 root root -"
      "d /var/cache/nss-himmelblau 0755 root root -"
    ];

    # Config files
    environment.etc = {
      "himmelblau/himmelblau.conf".text = ''
        [global]
        apply_policy = true
        authority_host = login.microsoftonline.com
        broker_socket_path = /var/run/himmelblaud/broker_sock
        cache_timeout = 300
        cn_name_mapping = true
        connection_timeout = 30
        db_path = /var/cache/himmelblaud/himmelblau.cache.db
        debug = ${lib.boolToString cfg.debugFlag}
        domains = ${builtins.head azureConfig.domains}
        enable_experimental_mfa = true
        enable_hello = true
        enable_sfa_fallback = false
        hello_pin_min_length = 6
        home_alias = CN
        home_attr = CN
        home_prefix = /home/
        hsm_pin_path = /var/lib/himmelblaud/hsm-pin
        hsm_type = tpm_bound_soft_if_possible
        id_attr_map = name
        idmap_range = 5000000-5999999
        join_type = join
        local_groups = users,networkmanager,wheel,docker
        selinux = false
        shell = /run/current-system/sw/bin/bash
        socket_path = /var/run/himmelblaud/socket
        task_socket_path = /var/run/himmelblaud/task_sock
        use_etc_skel = false
      '';
      "krb5.conf.d/krb5_himmelblau.conf".source =
        "${inputs.himmelblau}/src/config/krb5_himmelblau.conf";
    } // lib.optionalAttrs cfg.browserSso.chrome {
      "opt/chrome/native-messaging-hosts/linux_entra_sso.json".source =
        "${cfg.package.chromeNativeMessagingHost}/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json";
    } // lib.optionalAttrs cfg.browserSso.chromium {
      "chromium/native-messaging-hosts/linux_entra_sso.json".source =
        "${cfg.package.chromiumNativeMessagingHost}/etc/chromium/native-messaging-hosts/linux_entra_sso.json";
    };

    # DBus service for identity broker (required for browser SSO)
    services.dbus.packages = [ cfg.package ];

    # Firefox native messaging host
    programs.firefox.nativeMessagingHosts.packages = lib.mkIf cfg.browserSso.firefox [
      cfg.package.firefoxNativeMessagingHost
    ];

    # NSS modules
    system.nssModules = [ cfg.package ];
    system.nssDatabases.passwd = lib.mkOrder 1501 [ "himmelblau" ];
    system.nssDatabases.group  = lib.mkOrder 1501 [ "himmelblau" ];
    system.nssDatabases.shadow = lib.mkOrder 1501 [ "himmelblau" ];

    # PAM configuration
    security.pam.services = let
      genServiceCfg = service: {
        rules = let super = config.security.pam.services.${service}.rules; in {
          account.himmelblau = {
            order = super.account.unix.order - 10;
            control = "sufficient";
            modulePath = "${cfg.package}/lib/libpam_himmelblau.so";
            settings.ignore_unknown_user = true;
            settings.debug = cfg.debugFlag;
          };
          auth.himmelblau = {
            order = super.auth.unix.order - 10;
            control = "sufficient";
            modulePath = "${cfg.package}/lib/libpam_himmelblau.so";
            settings.mfa_poll_prompt = cfg.mfaSshWorkaroundFlag && service == "sshd";
            settings.debug = cfg.debugFlag;
          };
          session.himmelblau = {
            order = super.session.unix.order - 10;
            control = "optional";
            modulePath = "${cfg.package}/lib/libpam_himmelblau.so";
            settings.debug = cfg.debugFlag;
          };
        };
      };
      services = cfg.pamServices
        ++ lib.optional config.security.sudo.enable "sudo"
        ++ lib.optional (config.security.doas.enable or false) "doas"
        ++ lib.optional config.services.openssh.enable "sshd";
    in lib.genAttrs services genServiceCfg;

    # Systemd services
    systemd.services = let
      commonServiceConfig = {
        Type = "notify";
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        MemoryDenyWriteExecute = true;
      };
    in {
      himmelblaud = {
        description = "Himmelblau Authentication Daemon";
        wants = [ "chronyd.service" "ntpd.service" "network-online.target" ];
        before = [ "accounts-daemon.service" ];
        wantedBy = [ "multi-user.target" "accounts-daemon.service" ];
        upholds = [ "himmelblaud-tasks.service" ];
        serviceConfig = commonServiceConfig // {
          ExecStart = "${cfg.package}/bin/himmelblaud" + lib.optionalString cfg.debugFlag " -d";
          Restart = "on-failure";
          DynamicUser = true;
          # Add tss group for TPM access via tpm2-abrmd
          SupplementaryGroups = [ "tss" ];
          CacheDirectory = "himmelblaud";
          RuntimeDirectory = "himmelblaud";
          StateDirectory = "himmelblaud";
          PrivateTmp = true;
          # Disable PrivateDevices to allow tpmrm0 access for TPM binding
          PrivateDevices = false;
        };
      };

      himmelblaud-tasks = {
        description = "Himmelblau Local Tasks";
        after = [ "himmelblaud.service" ];
        requires = [ "himmelblaud.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.shadow pkgs.bash ];
        unitConfig = {
          ConditionPathExists = "/var/run/himmelblaud/task_sock";
        };
        serviceConfig = commonServiceConfig // {
          ExecStart = "${cfg.package}/bin/himmelblaud_tasks";
          Restart = "on-failure";
          RestartSec = "1s";
          User = "root";
          ProtectSystem = "strict";
          ReadWritePaths = "/home /var/run/himmelblaud /tmp /etc/krb5.conf.d /etc /var/lib /var/cache/nss-himmelblau /var/cache/himmelblau-policies";
          # Restrict to IPv4 only - himmelblaud_tasks fails on IPv6 connection errors
          # before falling back to IPv4, causing "federation provider not set" errors
          RestrictAddressFamilies = "AF_INET AF_UNIX";
          CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH";
          PrivateDevices = true;
        };
      };
    };
  };
}
