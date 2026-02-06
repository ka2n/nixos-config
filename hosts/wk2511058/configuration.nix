# Laptop-specific configuration
{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

let
  privateConfig = import ../../private/laptop.nix;
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

  environment.systemPackages = [
    pkgs.foot
    pkgs.brightnessctl
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      variant = "laptop";
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

  services.azure-entra = {
    enable = true;
    debugFlag = false;
    browserSso.chrome = true;
    pamServices = [ "passwd" "login" "systemd-user" "hyprlock" ];
    userMap.katsuma = privateConfig.username;
  };

  services.mdatp.enable = true;

  # Force RGB Full Range on HDMI (DELL S2722QC)
  hardware.display.dellS2722qcRgb.enable = true;
  hardware.display.outputs."HDMI-A-1".edid = config.hardware.display.dellS2722qcRgb.edidFilename;
  hardware.display.aquamarineBroadcastRgbFull.enable = true;

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
