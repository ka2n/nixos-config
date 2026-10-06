#!/bin/sh
set -eu

state_file="${XDG_RUNTIME_DIR:?}/caffeine-enabled"
exec 9> "$XDG_RUNTIME_DIR/caffeine-toggle.lock"
flock -x 9

if [ -e "$state_file" ]; then
    rm "$state_file"
    if ! systemctl --user start hypridle.service; then
        touch "$state_file"
        exit 1
    fi
    notify-send -t 2000 "Caffeine OFF" "Idle management restored"
else
    touch "$state_file"
    if ! systemctl --user stop hypridle.service; then
        rm "$state_file"
        exit 1
    fi
    notify-send -t 2000 "Caffeine ON" "Idle inhibition active"
fi
