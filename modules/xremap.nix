{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.xremap;
in {
  options.programs.xremap = {
    enable = mkEnableOption "xremap keyboard remapper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.xremap ];

    # Enable uinput for xremap
    hardware.uinput.enable = true;

    # udev rules for /dev/uinput access
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="users", MODE="0660"
    '';
  };
}
