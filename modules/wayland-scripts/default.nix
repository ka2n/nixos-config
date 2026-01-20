{ config, lib, pkgs, ... }:

let
  cfg = config.programs.wayland-scripts;

  # Terminal app wrapper (alacritty with specific class)
  mkTerminalWrapper = name: command: pkgs.writeShellScriptBin "wl-${name}" ''
    exec ${pkgs.alacritty}/bin/alacritty --class ${name} -e ${command}
  '';

  mkDesktopFile = { name, displayName, genericName, comment, icon ? null, categories ? [ "Utility" ] }: pkgs.makeDesktopItem {
    inherit name comment categories genericName;
    desktopName = displayName;
    exec = "wl-${name}";
    terminal = false;
    icon = icon;
  };

  # Terminal app wrappers
  bluetuiWrapper = mkTerminalWrapper "bluetui" "${pkgs.bluetui}/bin/bluetui";
  wiremixWrapper = mkTerminalWrapper "wiremix" "${pkgs.wiremix}/bin/wiremix";
  clipseWrapper = mkTerminalWrapper "clipse" "${pkgs.clipse}/bin/clipse";

  bluetuiDesktop = mkDesktopFile {
    name = "bluetui";
    displayName = "Bluetui";
    genericName = "Bluetooth Manager";
    comment = "TUI application for managing bluetooth devices";
    categories = [ "Utility" "Settings" ];
  };

  wiremixDesktop = mkDesktopFile {
    name = "wiremix";
    displayName = "Wiremix";
    genericName = "Audio Mixer";
    comment = "TUI mixer for PipeWire audio system";
    categories = [ "Audio" "Mixer" "Settings" ];
  };

  clipseDesktop = mkDesktopFile {
    name = "clipse";
    displayName = "Clipse";
    genericName = "Clipboard Manager";
    comment = "TUI clipboard manager with history";
    categories = [ "Utility" ];
  };

  # Rofi power menu
  rofiPowermenu = pkgs.writeShellScriptBin "rofi-powermenu" ''
    set -euo pipefail

    declare -a ENTRIES=(
        "󰌾  Lock	loginctl lock-session"
        "󰍃  Logout	riverctl exit"
        "󰤄  Suspend	systemctl suspend"
        "󰜉  Reboot	systemctl reboot"
        "󰐥  Shutdown	systemctl poweroff"
    )

    build_menu() {
        for entry in "''${ENTRIES[@]}"; do
            echo "''${entry%%	*}"
        done
    }

    get_command() {
        local selected="$1"
        for entry in "''${ENTRIES[@]}"; do
            local label="''${entry%%	*}"
            local cmd="''${entry#*	}"
            if [[ "$label" == "$selected" ]]; then
                echo "$cmd"
                return
            fi
        done
    }

    confirm() {
        local action="$1"
        local response
        response=$(echo -e "Yes\nNo" | ${pkgs.rofi}/bin/rofi -dmenu \
            -p "Confirm $action?" \
            -i \
            -no-custom \
            -theme-str 'window {width: 20%;}' \
            -theme-str 'listview {lines: 2;}' \
            2>/dev/null) || return 1

        [[ "$response" == "Yes" ]]
    }

    main() {
        local selected
        selected=$(build_menu | ${pkgs.rofi}/bin/rofi -dmenu \
            -p "Power" \
            -i \
            -no-custom \
            -theme-str 'window {width: 20%;}' \
            -theme-str 'listview {lines: 5;}' \
            2>/dev/null) || exit 0

        local cmd
        cmd=$(get_command "$selected")

        if [[ -z "$cmd" ]]; then
            exit 1
        fi

        local action
        action=$(echo "$selected" | sed 's/^[^ ]* *//')

        case "$action" in
            Logout|Reboot|Shutdown)
                confirm "$action" || exit 0
                ;;
        esac

        eval "$cmd"
    }

    main "$@"
  '';

in
{
  options.programs.wayland-scripts = {
    enable = lib.mkEnableOption "Wayland utility scripts";

    # Terminal app wrappers
    bluetui.enable = lib.mkEnableOption "bluetui with alacritty wrapper" // { default = true; };
    wiremix.enable = lib.mkEnableOption "wiremix with alacritty wrapper" // { default = true; };
    clipse.enable = lib.mkEnableOption "clipse with alacritty wrapper" // { default = true; };

    # Rofi scripts
    rofi-powermenu.enable = lib.mkEnableOption "rofi power menu (wlogout replacement)" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.flatten [
      # Terminal wrappers
      (lib.optional cfg.bluetui.enable [ bluetuiWrapper bluetuiDesktop ])
      (lib.optional cfg.wiremix.enable [ wiremixWrapper wiremixDesktop ])
      (lib.optional cfg.clipse.enable [ clipseWrapper clipseDesktop ])
      # Rofi scripts
      (lib.optional cfg.rofi-powermenu.enable rofiPowermenu)
    ];
  };
}
