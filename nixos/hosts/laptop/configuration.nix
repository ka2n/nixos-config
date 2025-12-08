# Laptop-specific configuration
{ config, pkgs, lib, inputs, ... }:

let
  himmelblauPkg = pkgs.callPackage ../../modules/himmelblau/package.nix {
    himmelblauSrc = inputs.himmelblau;
  };
in
{
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
    nativeMessagingHosts.packages = [
      himmelblauPkg.firefoxNativeMessagingHost
      pkgs.tridactyl-native
    ];
  };

  # Zen Browser with native messaging hosts
  programs.zen-browser.nativeMessagingHosts.packages = [
    himmelblauPkg.firefoxNativeMessagingHost
    pkgs.tridactyl-native
  ];

  system.stateVersion = "25.11";
}
