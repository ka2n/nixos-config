# Microsoft Intune + Defender ATP module
# Includes all related packages, overlays, and GNOME dependencies
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.mdatp.nixosModules.mdatp
  ];

  # Use bwrap wrappers for intune-portal and microsoft-identity-broker
  # to provide fake Ubuntu os-release/lsb-release without modifying system files
  nixpkgs.overlays = [
    (import ./overlays.nix)
  ];

  # Microsoft Intune
  services.intune.enable = true;

  # Microsoft Defender ATP
  services.mdatp.enable = true;

  # GNOME Desktop (required for Intune authentication)
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  services.gnome.games.enable = false;
  services.gnome.gnome-keyring.enable = true;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  # libsecret for credential storage
  environment.systemPackages = [ pkgs.libsecret ];
}
