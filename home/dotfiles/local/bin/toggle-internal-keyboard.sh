#!/bin/sh
# Toggle the ThinkPad internal keyboard on/off under River (Wayland).
# Wayland equivalent of the old `xinput --disable/--enable` approach.

dev="keyboard-1-1-AT_Translated_Set_2_keyboard"

state=$(riverctl list-input-configs | awk -v d="$dev" '
    $0 == d           { found = 1; next }
    found && /^\t/    { if ($1 == "events:") { print $2; exit } ; next }
    found && /^[^\t]/ { found = 0 }
')

if [ "$state" = "disabled" ]; then
    riverctl input "$dev" events enabled
    notify-send -t 2000 "Internal keyboard enabled"
else
    riverctl input "$dev" events disabled
    notify-send -t 2000 "Internal keyboard disabled"
fi
