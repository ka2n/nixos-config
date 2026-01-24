{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.programs.river-with-fallback;
  riverClassic = inputs.river-classic.packages.${pkgs.system}.default;

  # Fallback init script for users without ~/.config/river/init
  fallbackInit = pkgs.writeShellScript "river-fallback-init" ''
    # Session setup
    export XDG_CURRENT_DESKTOP=river
    export XDG_SESSION_TYPE=wayland
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    systemctl --user start river-session.target

    # Keybindings
    riverctl map normal Super Return spawn ${pkgs.alacritty}/bin/alacritty
    riverctl map normal Super D spawn "${pkgs.rofi}/bin/rofi -show drun"
    riverctl map normal Super+Shift Q close
    riverctl map normal Super+Shift E exit

    # Focus (vim-style)
    riverctl map normal Super J focus-view next
    riverctl map normal Super K focus-view previous
    riverctl map normal Super H focus-output previous
    riverctl map normal Super L focus-output next

    # Move windows
    riverctl map normal Super+Shift J swap next
    riverctl map normal Super+Shift K swap previous

    # Tags 1-9
    for i in $(seq 1 9); do
      tags=$((1 << ($i - 1)))
      riverctl map normal Super $i set-focused-tags $tags
      riverctl map normal Super+Shift $i set-view-tags $tags
    done

    # Layout
    riverctl default-layout rivertile
    rivertile -view-padding 4 -outer-padding 4 &

    # Autostart
    ${pkgs.waybar}/bin/waybar &
  '';

  # Wrapper: use ~/.config/river/init if exists, otherwise fallback
  riverWrapper = pkgs.writeShellScriptBin "river-with-fallback" ''
    if [ -x "$HOME/.config/river/init" ]; then
      exec ${riverClassic}/bin/river
    else
      exec ${riverClassic}/bin/river -c ${fallbackInit}
    fi
  '';

  # Custom session package for GDM
  riverSession = pkgs.runCommand "river-session" {
    passthru.providedSessions = [ "river" ];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/river.desktop << EOF
    [Desktop Entry]
    Name=River
    Comment=A dynamic tiling Wayland compositor
    Exec=${riverWrapper}/bin/river-with-fallback
    Type=Application
    DesktopNames=river
    EOF
  '';
in {
  options.programs.river-with-fallback = {
    enable = lib.mkEnableOption "River with fallback init for users without ~/.config/river/init";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ riverClassic ];
    services.displayManager.sessionPackages = [ riverSession ];
  };
}
