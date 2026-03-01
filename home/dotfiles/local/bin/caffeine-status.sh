#!/bin/sh
# Waybar custom module for caffeine status
# Outputs JSON: active when hypridle is stopped (caffeine ON)

if systemctl --user is-active --quiet hypridle.service; then
    printf '{"text": "󰒲", "tooltip": "Caffeine OFF", "class": "off"}\n'
else
    printf '{"text": "󰒳", "tooltip": "Caffeine ON", "class": "on"}\n'
fi
