{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.webcam.flickerPrevention;

  # power_line_frequency menu values: 0=Disabled, 1=50Hz, 2=60Hz
  freqValue = if cfg.frequency == 50 then "1" else "2";

  # Event-driven watcher: pins power_line_frequency for a single /dev/videoN.
  #
  # A one-shot `--set-ctrl` (the old udev approach) loses to Chrome, which
  # rewrites the control to its locale-derived value (60Hz for "JP", hardcoded
  # in Chromium's kCountriesUsing60Hz) on every stream start. Instead we
  # subscribe to V4L2 control-change events and re-assert the target value the
  # instant anything changes it. The 60Hz window lasts only until the event
  # wakes us (sub-millisecond), and control writes are independent of streaming
  # so this runs concurrently while Chrome holds the device.
  watcher = pkgs.writeShellApplication {
    name = "webcam-flicker-pin";
    runtimeInputs = [ pkgs.v4l-utils pkgs.gnugrep pkgs.coreutils ];
    text = ''
      dev="/dev/$1"
      target="${freqValue}"

      # Skip nodes that do not expose the control (metadata/output nodes etc.).
      if ! v4l2-ctl -d "$dev" --list-ctrls 2>/dev/null | grep -q power_line_frequency; then
        echo "no power_line_frequency on $dev, nothing to pin"
        exit 0
      fi

      pin() {
        local cur
        # Distinguish a read failure (transient EBUSY while streaming) from an
        # actual stale value; never blind-set on a failed read.
        if ! cur="$(v4l2-ctl -d "$dev" --get-ctrl=power_line_frequency 2>/dev/null | grep -oE '[0-9]+$')"; then
          echo "failed to read power_line_frequency on $dev"
          return 0
        fi
        if [ "$cur" != "$target" ]; then
          echo "pinning power_line_frequency on $dev: $cur -> $target"
          # Swallow transient write failures (grabbed/EBUSY during streaming);
          # the next event or poll re-asserts, avoiding a restart loop.
          v4l2-ctl -d "$dev" --set-ctrl=power_line_frequency="$target" \
            || echo "set failed on $dev (transient?), will retry"
        fi
      }

      # Event-driven, so Chrome's write is corrected within a sub-millisecond of
      # it landing. `--wait-for-event` blocks without burning CPU until an event
      # arrives or the timeout. It only catches one event per subscription,
      # leaving a tiny unsubscribed gap between iterations; the timeout is just a
      # slow safety net for the rare write that lands in that gap (30s is plenty
      # since the event path handles the common case). The `[ -e "$dev" ]` guard
      # ends the loop on unplug (BindsTo=dev-%i.device also stops the unit).
      while [ -e "$dev" ]; do
        pin
        timeout 30s v4l2-ctl -d "$dev" --wait-for-event=ctrl=power_line_frequency \
          >/dev/null 2>&1 || true
      done
    '';
  };
in {
  options.hardware.webcam.flickerPrevention = {
    enable = mkEnableOption "webcam flicker prevention via power line frequency";

    frequency = mkOption {
      type = types.enum [ 50 60 ];
      default = 50;
      description = ''
        Power line frequency (Hz) to pin on every webcam exposing the
        `power_line_frequency` V4L2 control. Applied to all detected capture
        devices, including hotplugged ones.
        - 50: East Japan (Tokyo, etc.)
        - 60: West Japan (Osaka, etc.)
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services."webcam-flicker@" = {
      description = "Pin power line frequency on /dev/%i";
      bindsTo = [ "dev-%i.device" ];
      after = [ "dev-%i.device" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${watcher}/bin/webcam-flicker-pin %i";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # Launch the watcher for every V4L2 capture node as it appears. The watcher
    # exits cleanly on nodes that lack the control, so matching all capture
    # nodes is harmless and also covers cameras exposing it on a non-zero index.
    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", ACTION=="add", ENV{ID_V4L_CAPABILITIES}=="*:capture:*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="webcam-flicker@%k.service"
    '';
  };
}
