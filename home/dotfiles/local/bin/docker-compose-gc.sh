# docker-compose-gc - Remove Docker Compose projects whose config directory no longer exists
# Useful for cleaning up after deleted git worktrees, removed project directories, etc.

# Command paths (replaced by Nix)
docker=@docker@
jq=@jq@

set -euo pipefail

DRY_RUN=false
VERBOSE=false

usage() {
  cat <<'USAGE'
Usage: docker-compose-gc [OPTIONS]

Remove Docker Compose projects whose config directory no longer exists.

Options:
  -n, --dry-run   Show what would be removed without removing anything
  -v, --verbose   Show detailed output
  -h, --help      Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

log() { echo "$@"; }
vlog() { $VERBOSE && echo "  $@" || true; }

orphans=()

while IFS= read -r line; do
  name=$(echo "$line" | $jq -r '.Name')
  config=$(echo "$line" | $jq -r '.ConfigFiles | split(",")[0]')
  dir=$(dirname "$config")

  if [[ ! -d "$dir" ]]; then
    orphans+=("$name")
    vlog "orphan: $name (missing: $dir)"
  else
    vlog "ok: $name ($dir)"
  fi
done < <($docker compose ls -a --format json | $jq -c '.[]')

if [[ ${#orphans[@]} -eq 0 ]]; then
  log "No orphaned Docker Compose projects found."
  exit 0
fi

log "Found ${#orphans[@]} orphaned project(s): ${orphans[*]}"

if $DRY_RUN; then
  log ""
  log "[dry-run] Would remove:"
fi

total_containers=0
total_volumes=0
total_networks=0

for project in "${orphans[@]}"; do
  containers=$($docker ps -a --filter "label=com.docker.compose.project=$project" -q)
  volumes=$($docker volume ls --filter "label=com.docker.compose.project=$project" -q)
  networks=$($docker network ls --filter "label=com.docker.compose.project=$project" -q)

  nc=$(echo "$containers" | grep -c . 2>/dev/null || echo 0)
  nv=$(echo "$volumes" | grep -c . 2>/dev/null || echo 0)
  nn=$(echo "$networks" | grep -c . 2>/dev/null || echo 0)

  total_containers=$((total_containers + nc))
  total_volumes=$((total_volumes + nv))
  total_networks=$((total_networks + nn))

  if $DRY_RUN; then
    log "  $project: ${nc} container(s), ${nv} volume(s), ${nn} network(s)"
    continue
  fi

  log "Removing $project..."

  if [[ -n "$containers" ]]; then
    vlog "removing ${nc} container(s)"
    echo "$containers" | xargs $docker rm -f > /dev/null
  fi

  if [[ -n "$volumes" ]]; then
    vlog "removing ${nv} volume(s)"
    echo "$volumes" | xargs $docker volume rm > /dev/null
  fi

  if [[ -n "$networks" ]]; then
    vlog "removing ${nn} network(s)"
    echo "$networks" | xargs $docker network rm 2>/dev/null || true
  fi
done

log ""
if $DRY_RUN; then
  log "Total: ${total_containers} container(s), ${total_volumes} volume(s), ${total_networks} network(s) would be removed"
  log "Run without --dry-run to remove them."
else
  log "Removed: ${total_containers} container(s), ${total_volumes} volume(s), ${total_networks} network(s)"
fi
