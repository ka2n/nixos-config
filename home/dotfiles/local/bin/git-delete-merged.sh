#!/bin/sh
set -eu

# Command paths (replaced by Nix)
git=@git@
git_wt=@git_wt@

show_help() {
    cat <<'EOF'
Usage: git delete-merged [--no-worktrees] [--no-branches] [--dry-run]

Delete merged branches and their worktrees.

Options:
  --no-worktrees  Skip deleting worktrees
  --no-branches   Skip deleting branches
  --dry-run       Show what would be deleted without actually deleting
  -h, --help      Show this help message

By default, both worktrees and branches are deleted.
EOF
}

with_worktrees=true
with_branches=true
dry_run=false

while [ $# -gt 0 ]; do
    case "$1" in
        --no-worktrees)
            with_worktrees=false
            shift
            ;;
        --no-branches)
            with_branches=false
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

# Get list of branches used by worktrees
get_worktree_branches() {
    $git worktree list --porcelain | grep '^branch refs/heads/' | sed 's|^branch refs/heads/||'
}

# Get merged branches excluding main/master and current branch
get_merged_branches() {
    $git branch --merged | sed 's/^[* +] //' | grep -v -E '^(main|master)$'
}

# Delete worktrees if requested
# Using git-wt which deletes both worktree and branch, and handles
# copied files (via wt.copyignored etc.) for safe deletion
if [ "$with_worktrees" = true ]; then
    main_worktree=$($git worktree list --porcelain | head -1 | sed 's/^worktree //')

    $git worktree list --porcelain | while read -r line; do
        case "$line" in
            "worktree "*)
                wt_path="${line#worktree }"
                ;;
            "branch refs/heads/"*)
                branch="${line#branch refs/heads/}"
                # Skip if it's the main worktree
                if [ "$wt_path" != "$main_worktree" ]; then
                    # Check if branch is merged
                    if $git branch --merged | sed 's/^[* +] //' | grep -qxF "$branch"; then
                        if [ "$dry_run" = true ]; then
                            echo "[dry-run] Would remove worktree + branch: $branch"
                        else
                            echo "Removing worktree + branch: $branch"
                            $git_wt -d "$branch"
                        fi
                    fi
                fi
                ;;
        esac
    done
fi

# Delete merged branches if requested
if [ "$with_branches" = true ]; then
    # Get worktree branches to exclude
    worktree_branches=$(get_worktree_branches)

    get_merged_branches | while read -r branch; do
        # Skip if branch is used by a worktree
        if echo "$worktree_branches" | grep -qxF "$branch"; then
            if [ "$dry_run" = true ]; then
                echo "[dry-run] Skipping (worktree): $branch"
            fi
            continue
        fi

        if [ "$dry_run" = true ]; then
            echo "[dry-run] Would delete branch: $branch"
        else
            echo "Deleting branch: $branch"
            $git branch -d "$branch"
        fi
    done
fi
