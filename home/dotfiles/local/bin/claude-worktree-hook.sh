# claude-worktree-hook - Route Claude Code's WorktreeCreate/WorktreeRemove
# hooks through git-wt, so agent isolation / EnterWorktree / --worktree all
# get the same layout (wt.basedir) and hooks (mise trust, direnv, docker gc)
# as worktrees created by hand.
#
# WorktreeCreate: stdin {"name": "<slug>", "cwd": "<repo>"} -> stdout: abs path
# WorktreeRemove: stdin {"worktree_path": "<abs path>"}

# Command paths (replaced by Nix)
cat=@cat@
jq=@jq@
git=@git@
git_wt=@git_wt@
head=@head@
tail=@tail@

set -euo pipefail

# git-wt shells out to git and looks up its wt.hook / wt.deletehook commands in
# PATH, which a hook process does not necessarily inherit in full.
export PATH="@hook_path@:$PATH"

input=$($cat)
event=$(printf '%s' "$input" | $jq -r '.hook_event_name // ""')

case "$event" in
WorktreeCreate)
  name=$(printf '%s' "$input" | $jq -r '.name // ""')
  cwd=$(printf '%s' "$input" | $jq -r '.cwd // ""')
  if [ -z "$name" ]; then
    echo "claude-worktree-hook: missing .name in WorktreeCreate payload" >&2
    exit 1
  fi
  if [ -n "$cwd" ]; then
    cd "$cwd"
  fi
  # git-wt prints the worktree path as the only line on stdout; post-create
  # hook chatter (direnv/mise) goes to stderr, but take the last line anyway.
  path=$($git_wt "$name" | $tail -n 1)
  if [ -z "$path" ]; then
    echo "claude-worktree-hook: git-wt returned no path for '$name'" >&2
    exit 1
  fi
  printf '%s\n' "$path"
  ;;
WorktreeRemove)
  worktree_path=$(printf '%s' "$input" | $jq -r '.worktree_path // ""')
  if [ -z "$worktree_path" ]; then
    echo "claude-worktree-hook: missing .worktree_path in WorktreeRemove payload" >&2
    exit 1
  fi
  # git-wt resolves its argument against the current repository, so run from the
  # main worktree (the first entry of `worktree list`) rather than wherever
  # Claude happened to be.
  main=$($git -C "$worktree_path" worktree list --porcelain | $head -n 1)
  main=${main#worktree }
  if [ -n "$main" ] && [ -d "$main" ]; then
    cd "$main"
  fi
  # -d is the safe delete: an unmerged branch is kept, the worktree still goes.
  # Keep stdout clean; Claude only surfaces stderr on failure.
  $git_wt -d "$worktree_path" >&2
  ;;
*)
  echo "claude-worktree-hook: unsupported hook event '$event'" >&2
  exit 1
  ;;
esac
