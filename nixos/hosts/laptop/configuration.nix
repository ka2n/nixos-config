# Laptop-specific configuration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
    ../../modules/microsoft-intune
  ];

  networking.hostName = "wk2511058";

  environment.systemPackages = with pkgs; [
    foot
  ];

  # Disable /etc/lsb-release
  environment.etc."lsb-release".enable = false;

  system.stateVersion = "25.11";
}
