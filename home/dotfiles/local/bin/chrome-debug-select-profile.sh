#!/usr/bin/env bash
set -euo pipefail

# Command paths (replaced by Nix)
jq=@jq@
fzf=@fzf@
google_chrome=@google_chrome@
wl_copy=@wl_copy@

CHROME_DATA_DIR="$HOME/.config/google-chrome"
AGENT_BROWSER_DIR="$HOME/chrome-agent-browser"
PORT="${1:-9222}"

# Parse profile names from Chrome's Local State
profiles=$($jq -r '.profile.info_cache | to_entries[] | "\(.key)\t\(.value.name)"' "$CHROME_DATA_DIR/Local State" 2>/dev/null)

if [[ -z "$profiles" ]]; then
  echo "No Chrome profiles found in $CHROME_DATA_DIR" >&2
  exit 1
fi

# Select profile with fzf (show name, return dir)
selected=$(echo "$profiles" | $fzf --with-nth=2 --delimiter='\t' --prompt="Select Chrome profile: " --height=~10)

if [[ -z "$selected" ]]; then
  echo "No profile selected" >&2
  exit 1
fi

profile_dir=$(echo "$selected" | cut -f1)
profile_name=$(echo "$selected" | cut -f2)

echo "Selected: $profile_name ($profile_dir)"

# Symlink profile into agent-browser data dir
mkdir -p "$AGENT_BROWSER_DIR"
if [[ -L "$AGENT_BROWSER_DIR/$profile_dir" ]]; then
  rm "$AGENT_BROWSER_DIR/$profile_dir"
elif [[ -d "$AGENT_BROWSER_DIR/$profile_dir" ]]; then
  rm -rf "$AGENT_BROWSER_DIR/$profile_dir"
fi
ln -s "$CHROME_DATA_DIR/$profile_dir" "$AGENT_BROWSER_DIR/$profile_dir"

echo "Launching Chrome on port $PORT ..."

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
  --remote-debugging-port="$PORT" \
  --user-data-dir="$AGENT_BROWSER_DIR" \
  --profile-directory="$profile_dir" \
  --no-first-run \
  --no-default-browser-check \
  2>"$_fifo"
