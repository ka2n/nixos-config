# VM-specific configuration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
  ];

  networking.hostName = "nixos-vm";

  # LUKS encryption (VM specific UUIDs)
  boot.initrd.luks.devices."luks-a2c231b3-4fdb-4a14-b227-f5a2bf4acc5c".device = 
    "/dev/disk/by-uuid/a2c231b3-4fdb-4a14-b227-f5a2bf4acc5c";

  # VM-specific packages (CPU rendering terminals for VirtualBox)
  environment.systemPackages = with pkgs; [
    foot  # CPU rendering, works in VM
  ];

  # VirtualBox guest additions
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.dragAndDrop = false;

  system.stateVersion = "25.11";
}
