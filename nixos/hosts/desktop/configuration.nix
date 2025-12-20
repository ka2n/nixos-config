# Desktop-specific configuration
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./disko.nix
    ../../common
  ];

  networking.hostName = "junior";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["ntfs"];

  environment.systemPackages = with pkgs; [
    foot
    ntfs3g
  ];

  system.stateVersion = "25.11";
}
