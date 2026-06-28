# git-wt-deletehook - Post-delete hook for git-wt worktrees

# Command paths (replaced by Nix)
mise=@mise@
jq=@jq@

set -euo pipefail

docker-compose-gc

# Remove this worktree from mise trusted_config_paths (added by git-wt-hook).
# mise has no per-element remove, so read → filter → unset → re-add.
current=$($mise settings get trusted_config_paths 2>/dev/null || echo '[]')
remaining=$(printf '%s' "$current" | $jq -c --arg p "$PWD" 'map(select(. != $p))')
if [ "$remaining" != "$current" ]; then
  $mise settings unset trusted_config_paths 2>/dev/null || true
  printf '%s' "$remaining" | $jq -r '.[]' | while IFS= read -r path; do
    [ -n "$path" ] && $mise settings add trusted_config_paths "$path"
  done
fi
