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

    # Enable uinput for xremap (user must be in 'uinput' group)
    # Also used by InputActions Standalone
    hardware.uinput.enable = true;
  };
}
