# Laptop-specific configuration
{ config, pkgs, pkgs-unstable, lib, inputs, llm-agents, ... }:

let
  privateConfigPath = ../../private/laptop.nix;
  privateConfig =
    if builtins.pathExists privateConfigPath
    then import privateConfigPath
    else { };
in {
  # Use latest stable kernel instead of zen for better thermal management
  boot.kernelPackages = pkgs.linuxPackages_latest;

  imports = [
    ./hardware-configuration.nix
    ../../common
    ../../modules/himmelblau
    inputs.mdatp.nixosModules.mdatp
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "wk2511058";

  # Suppress "Last MLO scan was too long ago" iwlmld WARNINGs that delay
  # screen restore after swaylock unlock on Lunar Lake / Wi-Fi 7 (BE-series).
  # See docs/himmelblau-troubleshooting.md (問題5).
  # Wi-Fi 7 MLO による Zoom/Meet パケロスの調査と対処は
  # docs/wifi7-mlo-packetloss.md（対処はルーター側で MLO のみ無効化）。
  networking.networkmanager.wifi.powersave = false;
  boot.extraModprobeConfig = ''
    options iwlwifi disable_11be=1 power_save=0
  '';

  environment.systemPackages = [
    pkgs.foot
    pkgs.brightnessctl
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable llm-agents;
      variant = "laptop";
      riverBackgroundColor = null;
    };
    users.katsuma = { ... }: {
      imports = [ ../../home ];
      home.username = "katsuma";
      home.homeDirectory = "/home/katsuma";
    };
  };

  # Local user for home-manager integration with himmelblau
  # UID is managed by himmelblau via user_map_file
  users.users.katsuma = {
    group = "users";
    home = "/home/katsuma";
    isNormalUser = true;
    createHome = true;
    uid = 1001;
    extraGroups = [ "networkmanager" "wheel" "docker" "uinput" "libvirtd" ];
  };

  # Display manager (greetd+tuigreet - Wayland native, supports himmelblau PAM_TEXT_INFO for MFA)
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  services.himmelblau = {
    enable = true;
    debugFlag = true;
    pamServices = [ "passwd" "login" "systemd-user" "swaylock" "greetd" ];
    userMap = lib.optionalAttrs (privateConfig ? username) {
      katsuma = privateConfig.username;
    };
    settings = {
      domain = [ (builtins.head (privateConfig.domains or [ "example.onmicrosoft.com" ])) ];
      # Enroll the device in Intune and apply its policies so the device
      # reports compliant in Entra. Needs /var/cache/himmelblau-policies
      # (provided by modules/himmelblau) and request_timeout below.
      apply_policy = true;
      cn_name_mapping = true;
      connection_timeout = 30;
      # Intune LinuxEnrollmentService (fef.*.manage.microsoft.com) is slow to
      # respond; upstream default 10 times out the enrollment send operation
      # ("timed out waiting on send operation"), leaving the device joined but
      # never MDM-enrolled. 30 lets enrollment complete.
      request_timeout = 30;
      enable_hello = true;
      enable_sfa_fallback = false;
      enable_experimental_mfa = true;
      hello_pin_min_length = 6;
      home_alias = "cn";
      home_attr = "cn";
      idmap_range = "5000000-5999999";
      local_groups = [ "users" "networkmanager" "wheel" "docker" "uinput" ];
      selinux = false;
      shell = "/run/current-system/sw/bin/bash";
      use_etc_skel = false;
      user_map_file = "/etc/himmelblau/user-map";
      offline_breakglass = {
        enabled = true;
        ttl = "7d";
      };
    };
  };

  services.mdatp.enable = true;

  # Organization-managed Claude Code settings (highest precedence, overrides user/project).
  # Encrypted with this host's age key only — see secrets/.sops.yaml.
  sops.secrets.claude-code-managed-settings = {
    sopsFile = ../../secrets/wk2511058/claude-code-managed-settings.enc;
    format = "binary";
    path = "/etc/claude-code/managed-settings.json";
    mode = "0444";
  };

  # Force RGB Full Range on HDMI (DELL S2722QC)
  hardware.display.dellS2722qcRgb.enable = true;
  hardware.display.outputs."HDMI-A-1".edid = config.hardware.display.dellS2722qcRgb.edidFilename;
  hardware.display.wlrootsBroadcastRgbFull.enable = true;

  # Webcam flicker prevention (50Hz for East Japan)
  hardware.webcam.flickerPrevention = {
    enable = true;
    frequency = 50;
  };

  # Intel NPU support (from unstable until nixpkgs-25.11 includes the module)
  hardware.graphics.extraPackages = [ pkgs-unstable.intel-npu-driver ];
  hardware.firmware = [ pkgs-unstable.intel-npu-driver.firmware ];

  system.stateVersion = "25.11";
}
