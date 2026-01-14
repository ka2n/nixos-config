#!/bin/sh
# Waybar module for hyprtag - real-time streaming status
# Monitors Hyprland events and outputs JSON on every tag change

# Commands (will be replaced by Nix)
socat=@socat@
jq=@jq@
hyprtagctl=@hyprtagctl@

# Function to get and output current status
output_status() {
    status=$($hyprtagctl status 2>/dev/null)

    if [ -z "$status" ]; then
        echo '{"text": "󰓹 —", "tooltip": "hyprtag not running", "class": "error"}'
        return
    fi

    active_tags=$(echo "$status" | $jq -r '.active_tags[]' 2>/dev/null)
    occupied_tags=$(echo "$status" | $jq -r '.occupied_tags[]' 2>/dev/null)

    if [ -z "$active_tags" ]; then
        active_tags="1"
    fi

    # Build display text - only show active or occupied tags
    text=""
    for i in 1 2 3 4 5 6 7 8 9; do
        is_active=$(echo "$active_tags" | grep -q "^$i$" && echo "yes" || echo "no")
        is_occupied=$(echo "$occupied_tags" | grep -q "^$i$" && echo "yes" || echo "no")

        if [ "$is_active" = "yes" ]; then
            # Active tag - bold
            text="$text <b>$i</b>"
        elif [ "$is_occupied" = "yes" ]; then
            # Occupied but not active - normal
            text="$text $i"
        fi
        # Empty tags are not shown
    done

    echo "{\"text\": \"󰓹$text\", \"tooltip\": \"Active: $(echo $active_tags | tr '\n' ' ')\\nOccupied: $(echo $occupied_tags | tr '\n' ' ')\", \"class\": \"tags\"}"
}

# Output initial status
output_status

# Monitor Hyprland event socket for workspace changes
$socat -u "UNIX-CONNECT:${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock" - | \
    while IFS= read -r line; do
        # Check for events that might change visible tags
        case "$line" in
            workspace*|activewindow*|movewindow*|openwindow*|closewindow*)
                output_status
                ;;
        esac
    done
