#!/bin/sh
# Waybar custom module for screen recording status
# Shows red circle when recording, hidden otherwise

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/screenrec.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    printf '{"text": "󰑋", "tooltip": "Recording... Click to stop", "class": "on"}\n'
else
    rm -f "$PIDFILE"
    printf '{"text": "", "tooltip": "", "class": "off"}\n'
fi
