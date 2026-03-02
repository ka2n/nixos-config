# git-wt-hook - Post-create hook for git-wt worktrees

# Command paths (replaced by Nix)
direnv=@direnv@
mise=@mise@

set -euo pipefail

if [ -f .envrc ]; then
  $direnv allow
fi

if [ -f mise.toml ] || [ -f .mise.toml ]; then
  $mise trust
fi
