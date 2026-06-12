#!/bin/sh
set -eu

ntn=@ntn@
jq=@jq@

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

payload=$(
  "$jq" -cn \
    --arg content "$content" \
    '{
      children: [
        {
          object: "block",
          type: "paragraph",
          paragraph: {
            rich_text: [
              {
                type: "text",
                text: {
                  content: $content
                }
              }
            ]
          }
        }
      ],
      position: {
        type: "start"
      }
    }'
)

exec "$ntn" api "/v1/blocks/$SCRATCHPAD_PAGE_ID/children" -X PATCH -d "$payload"
