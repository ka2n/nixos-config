# wlroots patch: Force Broadcast RGB = Full
# Fixes washed-out colors on HDMI/DP for Intel xe GPU
# (CEA modes default to Limited Range on Automatic setting)
#
# Related upstream issues:
#   https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/2310
#   https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4509
#   https://github.com/swaywm/sway/issues/3173
#   https://github.com/hyprwm/Hyprland/discussions/11607
{ config, lib, ... }:

{
  options.hardware.display.wlrootsBroadcastRgbFull = {
    enable = lib.mkEnableOption "wlroots patch to force Broadcast RGB = Full";
  };

  config = lib.mkIf config.hardware.display.wlrootsBroadcastRgbFull.enable {
    nixpkgs.overlays = [
      (final: prev: {
        wlroots_0_19 = prev.wlroots_0_19.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./wlroots-broadcast-rgb.patch
          ];
        });
      })
    ];
  };
}
