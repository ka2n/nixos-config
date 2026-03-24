#!/usr/bin/env bash
set -euo pipefail

# Command paths (replaced by Nix)
google_chrome=@google_chrome@

exec $google_chrome \
  --remote-debugging-port="${1:-9222}" \
  --user-data-dir="$HOME/chrome-agent-browser" \
  --no-first-run \
  --no-default-browser-check
