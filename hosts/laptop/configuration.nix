# VM-specific configuration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
  ];

  networking.hostName = "wk2511058";

  # VM-specific packages (CPU rendering terminals for VirtualBox)
  environment.systemPackages = with pkgs; [
    foot  # CPU rendering, works in VM
  ];

  services.intune.enable = true;

  system.stateVersion = "25.11";
}
