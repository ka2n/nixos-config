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
      (final: prev:
        let
          patchWlroots = pkg:
            pkg.overrideAttrs (oldAttrs: {
              patches = (oldAttrs.patches or [ ]) ++ [
                ./wlroots-broadcast-rgb.patch
              ];
            });
          patched = patchWlroots prev.wlroots_0_20;
        in {
          # river depends on wlroots 0.20 (both `wlroots` and `wlroots_0_20`
          # point at 0.20.0). Patching the old 0.19 attr had no effect.
          wlroots_0_20 = patched;
          wlroots = patched;
        })
    ];
  };
}
