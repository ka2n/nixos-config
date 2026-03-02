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

  # Display manager (greetd+tuigreet - Wayland native, lightweight TUI)
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  # VirtualBox guest additions
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.dragAndDrop = false;

  system.stateVersion = "25.11";
}
