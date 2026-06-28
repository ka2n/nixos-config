# git-wt-hook - Post-create hook for git-wt worktrees

# Command paths (replaced by Nix)
direnv=@direnv@
mise=@mise@

set -euo pipefail

if [ -f .envrc ]; then
  $direnv allow
fi

# Register the worktree root as a trusted prefix so all mise configs in the
# monorepo (including descendants) auto-trust without per-file prompts.
$mise settings add trusted_config_paths "$PWD"
