{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.webcam.flickerPrevention;

  # power_line_frequency values: 0=Disabled, 1=50Hz, 2=60Hz
  freqToValue = freq: if freq == 50 then "1" else "2";

  mkRule = name: freq: ''
    ACTION=="add", SUBSYSTEM=="video4linux", ATTR{index}=="0", ATTR{name}=="${name}", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl -d /dev/%k --set-ctrl=power_line_frequency=${freqToValue freq}"
  '';
in {
  options.hardware.webcam.flickerPrevention = {
    enable = mkEnableOption "webcam flicker prevention via power line frequency";

    devices = mkOption {
      type = types.attrsOf (types.enum [ 50 60 ]);
      default = {};
      example = {
        "Logitech StreamCam" = 50;
        "Integrated Camera: Integrated C" = 60;
      };
      description = ''
        Mapping of webcam names to power line frequency.
        Use `udevadm info -a /dev/video0 | grep name` to find device names.
        - 50: East Japan (Tokyo, etc.)
        - 60: West Japan (Osaka, etc.)
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.devices != {}) {
    services.udev.extraRules = concatStringsSep "\n" (mapAttrsToList mkRule cfg.devices);
  };
}
