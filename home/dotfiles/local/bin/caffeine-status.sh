#!/bin/sh
set -eu

if systemctl --user is-active --quiet caffeine.service; then
    printf '{"text": "󰒳", "tooltip": "Caffeine ON", "class": "on"}\n'
else
    printf '{"text": "󰒲", "tooltip": "Caffeine OFF", "class": "off"}\n'
fi
