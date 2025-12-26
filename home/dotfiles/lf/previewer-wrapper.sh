#!/bin/sh
# Sandboxed previewer using bubblewrap

# Create cache directory if it doesn't exist
mkdir -p "$HOME/.cache/lf"

# Get the file path from the first argument
file="$1"

# Determine the directory to mount (resolve symlinks)
if [ -n "$file" ]; then
  file_real="$(readlink -f "$file" 2>/dev/null || echo "$file")"
  file_dir="$(dirname "$file_real")"
else
  file_dir="$PWD"
fi

exec @bwrap@ \
  --ro-bind /nix /nix \
  --ro-bind /etc /etc \
  --ro-bind /run/current-system /run/current-system \
  --ro-bind "$file_dir" "$file_dir" \
  --ro-bind "$PWD" "$PWD" \
  --bind "$HOME/.cache/lf" "$HOME/.cache/lf" \
  --tmpfs /tmp \
  --proc /proc \
  --dev /dev \
  --unshare-net \
  --die-with-parent \
  --new-session \
  @previewer_script@ "$@"
