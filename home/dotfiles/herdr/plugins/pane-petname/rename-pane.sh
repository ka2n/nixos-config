#!/usr/bin/env bash
set -euo pipefail

# Command paths (replaced by Nix)
jq=@jq@
grep=@grep@

# Event payload: {"event":"pane_created","data":{"type":"pane_created","pane":{...}}}
json="${HERDR_PLUGIN_EVENT_JSON:-}"
[ -n "$json" ] || exit 0

pane_id=$(printf '%s' "$json" | $jq -r '.data.pane.pane_id // empty')
[ -n "$pane_id" ] || exit 0

# Skip panes that already carry a label (e.g. session restore re-fires pane.created)
label=$(printf '%s' "$json" | $jq -r '.data.pane.label // empty')
[ -z "$label" ] || exit 0

colors=(red orange amber yellow lime green teal cyan blue indigo violet magenta pink coral crimson olive navy silver gold ivory)
animals=(fox owl lynx otter panda wolf hare crane koala gecko heron mole raven bison viper stork tapir dingo lemur okapi swan toad finch quail ibis newt orca puma sloth kiwi yak ferret badger marten cobra egret gull mink weasel wombat)

# Re-pick on collision with existing pane labels (list may fail during startup; treat as no labels)
used=$("${HERDR_BIN_PATH:-herdr}" pane list 2>/dev/null | $jq -r '.result.panes[].label // empty' || true)
for ((i = 0; i < 20; i++)); do
  name="${colors[RANDOM % ${#colors[@]}]}-${animals[RANDOM % ${#animals[@]}]}"
  $grep -qxF "$name" <<<"$used" || break
done

exec "${HERDR_BIN_PATH:-herdr}" pane rename "$pane_id" "$name"
