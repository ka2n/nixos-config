#!/bin/sh
set -eu

rm -f "${XDG_RUNTIME_DIR:?}/caffeine-enabled" # legacy state file

if systemctl --user is-active --quiet caffeine.service; then
    systemctl --user stop caffeine.service
    notify-send -t 2000 "Caffeine OFF" "Idle management restored"
else
    systemd-run --user --collect --unit=caffeine --description="Caffeine idle inhibitor" \
        systemd-inhibit --what=idle --who=caffeine --why="Caffeine mode" sleep infinity
    notify-send -t 2000 "Caffeine ON" "Idle inhibition active"
fi
