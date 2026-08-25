# git-wt-hook - Post-create hook for git-wt worktrees

# Command paths (replaced by Nix)
direnv=@direnv@

set -euo pipefail

if [ -f .envrc ]; then
  $direnv allow
fi
