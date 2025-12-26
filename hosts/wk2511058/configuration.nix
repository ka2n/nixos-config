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

  environment.systemPackages = with pkgs; [
    foot
    brightnessctl
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.katsuma = { ... }: {
      imports = [ ../../home ];
      home.username = "katsuma";
      home.homeDirectory = "/home/katsuma";
    };
  };

  # Local user for home-manager integration with himmelblau
  users.users.katsuma = {
    uid = 5096008;
    group = "users";
    home = "/home/katsuma";
    isNormalUser = true;
    createHome = false;
  };

  services.azure-entra = {
    enable = true;
    browserSso.chrome = true;
    pamServices = [ "passwd" "login" "systemd-user" "hyprlock" "swaylock" ];
    userMap.katsuma = privateConfig.username;
  };

  services.mdatp.enable = true;

  # Firefox with native messaging hosts
  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages =
      [ himmelblauPkg.firefoxNativeMessagingHost pkgs.tridactyl-native ];
  };

  # Zen Browser with native messaging hosts
  programs.zen-browser.nativeMessagingHosts.packages =
    [ himmelblauPkg.firefoxNativeMessagingHost pkgs.tridactyl-native ];

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
