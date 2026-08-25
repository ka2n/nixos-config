# git-wt-deletehook - Post-delete hook for git-wt worktrees

# Command paths (replaced by Nix)
docker_compose_gc=@docker_compose_gc@

set -euo pipefail

$docker_compose_gc
