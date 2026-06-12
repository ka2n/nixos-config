#!/bin/sh
set -eu

ntn=@ntn@
jq=@jq@

TODO_DATA_SOURCE_ID="37d07061-d316-80cf-a8ee-000b7f823f75"
TASK_TITLE_PROPERTY="Task name"

if [ $# -ne 1 ]; then
  echo "Usage: ntn-todo-add <task title>" >&2
  exit 1
fi

content=$(printf '%s' "$1" | tr -d '\r')
if [ -z "$content" ]; then
  echo "Error: task title is empty" >&2
  exit 1
fi

payload=$(
  "$jq" -cn \
    --arg data_source_id "$TODO_DATA_SOURCE_ID" \
    --arg title_property "$TASK_TITLE_PROPERTY" \
    --arg content "$content" \
    '{
      parent: { data_source_id: $data_source_id },
      properties: {
        ($title_property): {
          title: [
            {
              text: {
                content: $content
              }
            }
          ]
        }
      }
    }'
)

exec "$ntn" api /v1/pages -d "$payload"
