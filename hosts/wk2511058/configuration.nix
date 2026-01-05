# Laptop-specific configuration
{ config, pkgs, lib, inputs, ... }:

let
  himmelblauPkg = pkgs.callPackage ../../modules/himmelblau/package.nix {
    himmelblauSrc = inputs.himmelblau;
  };
  privateConfig = import ../../private/laptop.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../../common
    ../../modules/himmelblau
    inputs.mdatp.nixosModules.mdatp
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "wk2511058";

  #boot.kernelPackages = pkgs.linuxPackages_zen;

  environment.systemPackages = with pkgs; [ foot brightnessctl ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs himmelblauPkg;
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
    extraGroups = [ "networkmanager" "wheel" "docker" "uinput" ];
  };

  services.azure-entra = {
    enable = true;
    browserSso.chrome = true;
    pamServices = [ "passwd" "login" "systemd-user" "hyprlock" "swaylock" ];
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

  system.stateVersion = "25.11";
}
