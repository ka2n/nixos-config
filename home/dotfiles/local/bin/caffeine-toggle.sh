#!/bin/sh
# Toggle hypridle service (caffeine mode)
# When hypridle is stopped, idle actions (lock, screen off, suspend) are inhibited.

if systemctl --user is-active --quiet hypridle.service; then
    systemctl --user stop hypridle.service
    notify-send -t 2000 "Caffeine ON" "Idle inhibition active"
else
    systemctl --user start hypridle.service
    notify-send -t 2000 "Caffeine OFF" "Idle management restored"
fi
