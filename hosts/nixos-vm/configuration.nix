# VM-specific configuration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
  ];

  networking.hostName = "nixos-vm";

  # VM-specific packages (CPU rendering terminals for VirtualBox)
  environment.systemPackages = with pkgs; [
    foot  # CPU rendering, works in VM
  ];

  # Display manager (GDM)
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  security.pam.services.gdm.enableGnomeKeyring = true;

  # VirtualBox guest additions
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.dragAndDrop = false;

  system.stateVersion = "25.11";
}
