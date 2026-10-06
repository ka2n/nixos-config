#!/bin/sh
set -eu

if [ -e "${XDG_RUNTIME_DIR:?}/caffeine-enabled" ]; then
    printf '{"text": "󰒳", "tooltip": "Caffeine ON", "class": "on"}\n'
else
    printf '{"text": "󰒲", "tooltip": "Caffeine OFF", "class": "off"}\n'
fi
