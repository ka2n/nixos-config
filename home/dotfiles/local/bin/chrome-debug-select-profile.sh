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

# Collect profiles as TSV: source<TAB>profile_dir<TAB>display_name
# - source=chrome : profile lives under $CHROME_DATA_DIR (linked into agent dir on launch)
# - source=agent  : profile created locally under $AGENT_BROWSER_DIR (used as-is)
profiles=""

if [[ -f "$CHROME_DATA_DIR/Local State" ]]; then
  chrome_profiles=$($jq -r '.profile.info_cache | to_entries[] | "chrome\t\(.key)\t\(.value.name)"' "$CHROME_DATA_DIR/Local State" 2>/dev/null || true)
  if [[ -n "$chrome_profiles" ]]; then
    profiles+="$chrome_profiles"$'\n'
  fi
fi

if [[ -f "$AGENT_BROWSER_DIR/Local State" ]]; then
  # Only include profiles whose dir actually exists in the agent dir AND is not a symlink
  # (symlinks here just point back to google-chrome profiles, already listed above).
  while IFS=$'\t' read -r dir name; do
    [[ -z "$dir" ]] && continue
    target="$AGENT_BROWSER_DIR/$dir"
    if [[ -d "$target" && ! -L "$target" ]]; then
      profiles+="agent"$'\t'"$dir"$'\t'"$name"$'\n'
    fi
  done < <($jq -r '.profile.info_cache | to_entries[] | "\(.key)\t\(.value.name)"' "$AGENT_BROWSER_DIR/Local State" 2>/dev/null || true)
fi

# Strip trailing newline
profiles="${profiles%$'\n'}"

if [[ -z "$profiles" ]]; then
  echo "No Chrome profiles found in $CHROME_DATA_DIR or $AGENT_BROWSER_DIR" >&2
  exit 1
fi

# Select profile with fzf (show "name [source]", return all fields)
selected=$(echo "$profiles" \
  | awk -F'\t' '{ printf "%s\t%s\t%s\t%s [%s]\n", $1, $2, $3, $3, $1 }' \
  | $fzf --with-nth=4 --delimiter='\t' --prompt="Select Chrome profile: " --height=~10)

if [[ -z "$selected" ]]; then
  echo "No profile selected" >&2
  exit 1
fi

source=$(echo "$selected" | cut -f1)
profile_dir=$(echo "$selected" | cut -f2)
profile_name=$(echo "$selected" | cut -f3)

echo "Selected: $profile_name ($profile_dir) [$source]"

mkdir -p "$AGENT_BROWSER_DIR"

case "$source" in
  chrome)
    # Symlink chrome profile into agent-browser data dir (replace existing link/dir).
    if [[ -L "$AGENT_BROWSER_DIR/$profile_dir" ]]; then
      rm "$AGENT_BROWSER_DIR/$profile_dir"
    elif [[ -d "$AGENT_BROWSER_DIR/$profile_dir" ]]; then
      rm -rf "$AGENT_BROWSER_DIR/$profile_dir"
    fi
    ln -s "$CHROME_DATA_DIR/$profile_dir" "$AGENT_BROWSER_DIR/$profile_dir"
    ;;
  agent)
    # Profile already lives in the agent dir; nothing to link.
    ;;
esac

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
