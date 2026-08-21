#!/bin/sh
# Open satty with the most recent image from clipse clipboard history
# Command paths (replaced by Nix)
jq=@jq@
satty=@satty@
notify_send=@notify_send@

history_file="$HOME/.config/clipse/clipboard_history.json"

if [ ! -f "$history_file" ]; then
  $notify_send -u critical "satty" "clipse history not found: $history_file"
  exit 1
fi

# clipse stores history newest-first; look only at the 10 most recent
# operations, then pick image entries (real filePath) among them
files=$($jq -r '.clipboardHistory[:10] | .[] | select(.filePath != null and .filePath != "null") | .filePath' "$history_file")

for f in $files; do
  if [ -f "$f" ]; then
    exec $satty -f "$f"
  fi
done

$notify_send -u critical "satty" "No image found in the last 10 clipboard entries"
exit 1
