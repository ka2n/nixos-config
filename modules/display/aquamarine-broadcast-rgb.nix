# Aquamarine patch: Force Broadcast RGB = Full
# Fixes washed-out colors on HDMI for Intel xe GPU
# (CEA modes default to Limited Range on Automatic setting)
{ config, lib, ... }:

{
  options.hardware.display.aquamarineBroadcastRgbFull = {
    enable = lib.mkEnableOption "Aquamarine patch to force Broadcast RGB = Full";
  };

  config = lib.mkIf config.hardware.display.aquamarineBroadcastRgbFull.enable {
    nixpkgs.overlays = [
      (final: prev: {
        aquamarine = prev.aquamarine.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./aquamarine-broadcast-rgb.patch
          ];
        });
      })
    ];
  };
}
