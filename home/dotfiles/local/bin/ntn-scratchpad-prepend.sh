#!/bin/sh
set -eu

ntn=@ntn@
jq=@jq@
mktemp=@mktemp@
cat_cmd=@cat@

SCRATCHPAD_PAGE_ID="c6907061-d316-8309-af67-01247566d65d"

if [ $# -ne 1 ]; then
  echo "Usage: ntn-scratchpad-prepend <content>" >&2
  exit 1
fi

content=$(printf '%s' "$1" | tr -d '\r')
if [ -z "$content" ]; then
  echo "Error: content is empty" >&2
  exit 1
fi

tmp=$("$mktemp")
trap 'rm -f "$tmp"' EXIT

"$ntn" pages get "$SCRATCHPAD_PAGE_ID" --json \
  | "$jq" -r '.markdown.markdown' > "$tmp"

existing=$("$cat_cmd" "$tmp")

if [ -n "$existing" ]; then
  updated=$(printf '%s\n\n%s' "$content" "$existing")
else
  updated=$content
fi

exec "$ntn" pages update "$SCRATCHPAD_PAGE_ID" --content "$updated"
