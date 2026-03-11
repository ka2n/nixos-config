# Copy to laptop.nix and fill in your values
# Then register it in the git index (required for Nix flakes to see the file):
#
#   BLOB=$(git hash-object -w private/laptop.nix)
#   git update-index --add --cacheinfo 100644,$BLOB,private/laptop.nix
#   git update-index --skip-worktree private/laptop.nix
#
# Note: `git add -f` and `--assume-unchanged` do NOT work reliably together.
# Use `git hash-object -w` + `--cacheinfo` to bypass .gitignore and index flags,
# and `--skip-worktree` (not `--assume-unchanged`) to prevent committing local changes.
{
  domains = ["your-tenant.onmicrosoft.com"];
  username = "user@example.com";
}
