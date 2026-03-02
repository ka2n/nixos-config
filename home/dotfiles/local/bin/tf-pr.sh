#!/bin/sh
set -euo pipefail

# Command paths (replaced by Nix)
gh=@gh@
git=@git@
jq=@jq@

show_help() {
    cat <<'EOF'
Usage:
  tf-pr <PR_NUM> [plan|apply]     Direct PR number mode
  tf-pr plan --guess              Auto-detect PR from git log
  tf-pr apply --guess             Auto-detect PR from git log
EOF
}

get_repo_info() {
    OWNER=$($gh repo view --json owner -q '.owner.login')
    REPO=$($gh repo view --json name -q '.name')
}

run_tfcmt() {
    pr_num="$1"
    action="$2"
    terraform init
    exec tfcmt -owner "$OWNER" -repo "$REPO" -pr "$pr_num" "$action" -- terraform "$action"
}

guess_pr() {
    # Find merge commits that changed files under the current directory
    pr_nums=$($git log --merges --format='%s' -- . 2>/dev/null \
        | grep -oP '#\K[0-9]+' \
        | head -10 \
        | sort -un)

    if [ -z "$pr_nums" ]; then
        echo "No PRs found for files in the current directory." >&2
        exit 1
    fi

    # Collect PR info
    i=0
    for pr in $pr_nums; do
        info=$($gh pr view "$pr" --json number,title,url 2>/dev/null) || continue
        i=$((i + 1))
        num=$(echo "$info" | $jq -r '.number')
        title=$(echo "$info" | $jq -r '.title')
        url=$(echo "$info" | $jq -r '.url')
        eval "pr_num_$i=$num"
        printf "%d) #%s %s\n   %s\n" "$i" "$num" "$title" "$url"
    done

    if [ "$i" -eq 0 ]; then
        echo "No valid PRs found." >&2
        exit 1
    fi

    printf "\nSelect PR number [1-%d]: " "$i"
    read -r selection

    if [ -z "$selection" ] || [ "$selection" -lt 1 ] 2>/dev/null || [ "$selection" -gt "$i" ] 2>/dev/null; then
        echo "Invalid selection." >&2
        exit 1
    fi

    eval "SELECTED_PR=\$pr_num_$selection"
}

# Parse arguments
if [ $# -lt 1 ]; then
    show_help >&2
    exit 1
fi

# Check for --guess mode: tf-pr plan --guess / tf-pr apply --guess
if [ $# -eq 2 ] && [ "$2" = "--guess" ]; then
    ACTION="$1"
    if [ "$ACTION" != "plan" ] && [ "$ACTION" != "apply" ]; then
        echo "Error: action must be 'plan' or 'apply'" >&2
        exit 1
    fi
    get_repo_info
    guess_pr
    run_tfcmt "$SELECTED_PR" "$ACTION"
fi

# Direct mode: tf-pr <PR_NUM> [plan|apply]
PR_NUM="$1"
ACTION="${2:-plan}"

if [ "$ACTION" != "plan" ] && [ "$ACTION" != "apply" ]; then
    echo "Error: action must be 'plan' or 'apply'" >&2
    exit 1
fi

get_repo_info
run_tfcmt "$PR_NUM" "$ACTION"
