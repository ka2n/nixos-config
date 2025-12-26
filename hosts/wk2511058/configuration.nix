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
  ];

  networking.hostName = "wk2511058";

  #boot.kernelPackages = pkgs.linuxPackages_zen;

  environment.systemPackages = with pkgs; [
    foot
    brightnessctl
    # Standalone Home Manager for himmelblau user (users.users not available)
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../../home
        {
          home.username = privateConfig.username;
          home.homeDirectory = "/home/katsuma";
          home.stateVersion = "25.11";
        }
      ];
    }).activationPackage
  ];

  services.azure-entra = {
    enable = true;
    browserSso.chrome = true;
    pamServices = [ "passwd" "login" "systemd-user" "hyprlock" "swaylock" ];
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
