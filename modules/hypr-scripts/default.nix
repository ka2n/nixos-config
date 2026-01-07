{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hypr-scripts;

  # Terminal app wrapper (alacritty with specific class)
  mkTerminalWrapper = name: command: pkgs.writeShellScriptBin "hypr-${name}" ''
    exec ${pkgs.alacritty}/bin/alacritty --class ${name} -e ${command}
  '';

  mkDesktopFile = { name, displayName, genericName, comment, icon ? null, categories ? [ "Utility" ] }: pkgs.makeDesktopItem {
    inherit name comment categories genericName;
    desktopName = displayName;
    exec = "hypr-${name}";
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

  # Rofi scripts
  rofiPowermenu = pkgs.writeShellScriptBin "rofi-powermenu" ''
    set -euo pipefail

    declare -a ENTRIES=(
        "󰌾  Lock	loginctl lock-session"
        "󰍃  Logout	hyprctl dispatch exit"
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

  # Focus-or-launch script (run-or-raise for Hyprland)
  hyprFocusOrLaunch = pkgs.writeShellScriptBin "hypr-focus-or-launch" ''
    set -euo pipefail

    # Command paths (replaced by Nix)
    hyprctl=${lib.getExe' pkgs.hyprland "hyprctl"}
    jq=${lib.getExe pkgs.jq}

    show_help() {
      cat <<EOF
Usage: hypr-focus-or-launch [-s special] <class-pattern> <launch-command>

Focus an existing window matching the class pattern, or launch a new instance.

Options:
  -s special      Toggle the specified special workspace after focus/launch
  -h, --help      Show this help message

Arguments:
  class-pattern   Regex pattern to match window class (e.g., "firefox", "Alacritty")
  launch-command  Command to execute if no matching window is found

Examples:
  hypr-focus-or-launch firefox firefox
  hypr-focus-or-launch "^Alacritty$" alacritty
  hypr-focus-or-launch -s cal "^chrome-notion" "gtk-launch notion"
EOF
    }

    # Show help if requested
    if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
      show_help
      exit 0
    fi

    # Parse options
    SPECIAL_WS=""
    while getopts "s:h" opt; do
      case $opt in
        s) SPECIAL_WS="$OPTARG" ;;
        h) show_help; exit 0 ;;
        *) show_help >&2; exit 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    # Validate arguments
    if [[ $# -ne 2 ]]; then
      echo "Error: Expected 2 arguments, got $#" >&2
      echo >&2
      show_help >&2
      exit 1
    fi

    CLASS_PATTERN="$1"
    LAUNCH_CMD="$2"

    # Find window by class (regex match)
    ADDRESS=$($hyprctl clients -j | \
      $jq -r ".[] | select(.class | test(\"$CLASS_PATTERN\")) | .address" | \
      head -1)

    if [ -z "$ADDRESS" ]; then
      # Window doesn't exist -> launch
      $hyprctl dispatch exec "$LAUNCH_CMD"
      echo "Launched: $LAUNCH_CMD"
    else
      # Window exists -> toggle or focus
      if [[ -n "$SPECIAL_WS" ]]; then
        $hyprctl dispatch togglespecialworkspace "$SPECIAL_WS"
        echo "Toggled special workspace: $SPECIAL_WS"
      else
        $hyprctl dispatch focuswindow "address:$ADDRESS"
        echo "Focused window: $ADDRESS"
      fi
    fi
  '';

  rofiKeybindings = pkgs.writeShellScriptBin "rofi-keybindings" ''
    set -euo pipefail

    modmask_to_text() {
        local mask="$1"
        case "$mask" in
            0)  echo "" ;;
            1)  echo "Shift" ;;
            4)  echo "Ctrl" ;;
            5)  echo "Shift+Ctrl" ;;
            8)  echo "Alt" ;;
            9)  echo "Shift+Alt" ;;
            12) echo "Ctrl+Alt" ;;
            13) echo "Shift+Ctrl+Alt" ;;
            64) echo "Super" ;;
            65) echo "Super+Shift" ;;
            68) echo "Super+Ctrl" ;;
            69) echo "Super+Shift+Ctrl" ;;
            72) echo "Super+Alt" ;;
            73) echo "Super+Shift+Alt" ;;
            76) echo "Super+Ctrl+Alt" ;;
            77) echo "Super+Shift+Ctrl+Alt" ;;
            *)  echo "Mod$mask" ;;
        esac
    }

    get_bindings() {
        ${pkgs.hyprland}/bin/hyprctl binds -j | ${pkgs.jq}/bin/jq -r '
            .[] | select(.description | length > 0) |
            [.modmask, .key, .description, .dispatcher, (.arg // "")] |
            @tsv
        ' | while IFS=$'\t' read -r modmask key description dispatcher arg; do
            local mod
            mod=$(modmask_to_text "$modmask")

            local combo
            if [[ -n "$mod" ]]; then
                combo="''${mod}+''${key}"
            else
                combo="''${key}"
            fi

            printf "%-30s  →  %s\t%s\t%s\n" "$combo" "$description" "$dispatcher" "$arg"
        done
    }

    prioritize_entries() {
        ${pkgs.gawk}/bin/awk '
        {
            line = $0
            prio = 50

            if (/Terminal/) prio = 0
            if (/Browser/) prio = 1
            if (/File manager/) prio = 2
            if (/App launcher/) prio = 3
            if (/Close window/) prio = 8
            if (/Keybindings/) prio = 99

            printf "%d\t%s\n", prio, line
        }' | sort -t$'\t' -k1,1n -k2,2 | cut -f2-
    }

    main() {
        local bindings
        bindings=$(get_bindings | sort -u | prioritize_entries)

        if [[ -z "$bindings" ]]; then
            echo "No keybindings found" >&2
            exit 1
        fi

        local selected
        selected=$(echo "$bindings" | cut -f1 | ${pkgs.rofi}/bin/rofi -dmenu \
            -p "Keybindings" \
            -i \
            -no-custom \
            -theme-str 'window {width: 60%;}' \
            -theme-str 'listview {lines: 20;}' \
            2>/dev/null) || exit 0

        local match
        match=$(echo "$bindings" | grep -F "$selected" | head -1)

        if [[ -n "$match" ]]; then
            local dispatcher arg
            dispatcher=$(echo "$match" | cut -f2)
            arg=$(echo "$match" | cut -f3)

            ${pkgs.hyprland}/bin/hyprctl dispatch "$dispatcher" "$arg"
        fi
    }

    main "$@"
  '';

in
{
  options.programs.hypr-scripts = {
    enable = lib.mkEnableOption "Hyprland utility scripts";

    # Terminal app wrappers
    bluetui.enable = lib.mkEnableOption "bluetui with alacritty wrapper" // { default = true; };
    wiremix.enable = lib.mkEnableOption "wiremix with alacritty wrapper" // { default = true; };
    clipse.enable = lib.mkEnableOption "clipse with alacritty wrapper" // { default = true; };

    # Rofi scripts
    rofi-powermenu.enable = lib.mkEnableOption "rofi power menu (wlogout replacement)" // { default = true; };
    rofi-keybindings.enable = lib.mkEnableOption "rofi keybindings viewer" // { default = true; };

    # Utility scripts
    focus-or-launch.enable = lib.mkEnableOption "focus-or-launch (run-or-raise for Hyprland)" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.flatten [
      # Terminal wrappers
      (lib.optional cfg.bluetui.enable [ bluetuiWrapper bluetuiDesktop ])
      (lib.optional cfg.wiremix.enable [ wiremixWrapper wiremixDesktop ])
      (lib.optional cfg.clipse.enable [ clipseWrapper clipseDesktop ])
      # Rofi scripts
      (lib.optional cfg.rofi-powermenu.enable rofiPowermenu)
      (lib.optional cfg.rofi-keybindings.enable rofiKeybindings)
      # Utility scripts
      (lib.optional cfg.focus-or-launch.enable hyprFocusOrLaunch)
    ];
  };
}
