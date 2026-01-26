#!/bin/sh
set -eu

# Command paths (replaced by Nix)
readability=@readability@
git=@git@
wl_paste=@wl_paste@
sed=@sed@
mkdir=@mkdir@
mv=@mv@

usage() {
  cat <<EOF
Usage: save-url-to-doc [OPTIONS] [URL]

Save web page content as markdown to external-docs directory.

Arguments:
  URL    URL to fetch (default: read from clipboard)

Options:
  -h, --help    Show this help message

Output:
  Saves to \$(git rev-parse --show-toplevel)/external-docs/<sanitized-url>.md
EOF
}

# Parse options
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

# Get URL from clipboard or argument
if [ $# -ge 1 ]; then
  url="$1"
else
  url=$($wl_paste)
fi

if [ -z "$url" ]; then
  echo "Error: No URL provided" >&2
  exit 1
fi

# Create temp file with trap for cleanup
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Fetch and convert to markdown
$readability --format markdown "$url" > "$tmp"

# Generate output path under git root/external-docs
root=$($git rev-parse --show-toplevel)
sanitized=$(echo "$url" | $sed 's|https\?://||; s|[/?&=]|_|g')
out="$root/external-docs/${sanitized}.md"

$mkdir -p "$(dirname "$out")"
$mv "$tmp" "$out"
trap - EXIT

echo "Saved to: $out"
