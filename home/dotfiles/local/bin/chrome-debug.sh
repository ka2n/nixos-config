#!/usr/bin/env bash
set -euo pipefail

# Command paths (replaced by Nix)
google_chrome=@google_chrome@
wl_copy=@wl_copy@

# Remove stale singleton files to avoid "Opening in existing browser session"
rm -f "$HOME/chrome-agent-browser/Singleton"*

_fifo=$(mktemp -u)
mkfifo "$_fifo"

# Monitor Chrome's stderr: print to terminal and copy DevTools URL to clipboard
{
  while IFS= read -r _line; do
    printf '%s\n' "$_line" >&2
    if [[ "$_line" =~ (ws://[^[:space:]]+) ]]; then
      printf '%s' "${BASH_REMATCH[1]}" | $wl_copy
    fi
  done < "$_fifo"
  rm -f "$_fifo"
} &

exec $google_chrome \
  --remote-debugging-port="${1:-9222}" \
  --user-data-dir="$HOME/chrome-agent-browser" \
  --profile-directory="Default Agentic" \
  --no-first-run \
  --no-default-browser-check \
  2>"$_fifo"
