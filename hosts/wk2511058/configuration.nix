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
  # See docs/himmelblau-troubleshooting.md (問題7).
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
      # 2.x uses `domains` (list); 3.x renamed this to `domain`.
      domains = [ (builtins.head (privateConfig.domains or [ "example.onmicrosoft.com" ])) ];
      allow_console_password_only = false;
      # Keep false while Intune backend rejects this device's CSR.
      # When apply_policy=true and is_intune_enrolled=false, the daemon
      # forces password+MFA on every auth and never reaches the Hello PIN
      # branch (himmelblau.rs:1619-1628 `intune_enrollment_required`).
      # Flip back to true after admin unblocks Intune enrollment.
      # See docs/himmelblau-troubleshooting.md 問題8.
      apply_policy = false;
      cn_name_mapping = true;
      connection_timeout = 30;
      request_timeout = 30;
      enable_hello = true;
      enable_sfa_fallback = false;
      enable_experimental_mfa = true;
      hello_pin_min_length = 6;
      # 2.x enum uses uppercase ("UUID" | "SPN" | "CN"); 3.x accepts lowercase.
      home_alias = "CN";
      home_attr = "CN";
      idmap_range = "5000000-5999999";
      local_groups = [ "users" "networkmanager" "wheel" "docker" "uinput" ];
      selinux = false;
      shell = "/run/current-system/sw/bin/bash";
      use_etc_skel = false;
      # `user_map_file` / `offline_breakglass` are 3.x-only options.
      # cn_name_mapping + enable_sfa_fallback above cover the equivalent
      # behaviors on 2.x.
    };
  };

  services.mdatp.enable = true;

  # Force RGB Full Range on HDMI (DELL S2722QC)
  hardware.display.dellS2722qcRgb.enable = true;
  hardware.display.outputs."HDMI-A-1".edid = config.hardware.display.dellS2722qcRgb.edidFilename;
  hardware.display.wlrootsBroadcastRgbFull.enable = true;

  # Webcam flicker prevention (50Hz for East Japan)
  hardware.webcam.flickerPrevention = {
    enable = true;
    devices = {
      "Logitech StreamCam" = 50;
      "Integrated Camera: Integrated C" = 50;
    };
  };

  # Intel NPU support (from unstable until nixpkgs-25.11 includes the module)
  hardware.graphics.extraPackages = [ pkgs-unstable.intel-npu-driver ];
  hardware.firmware = [ pkgs-unstable.intel-npu-driver.firmware ];

  system.stateVersion = "25.11";
}
