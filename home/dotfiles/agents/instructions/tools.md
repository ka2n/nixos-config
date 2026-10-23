## Tools

### Nix Development Shells
- When a project has `flake.nix`, use `nix develop` as needed to get the development environment

### Missing Commands
When a command is not found, try these approaches:
- `, <cmd>` - Run command with temporary package (home-manager's comma). Example: `, cowsay hello`
- `nix-shell -p '<pkg>'` - Enter shell with package available. Example: `nix-shell -p jq`
- e.g. gcloud command: `nix-shell -p google-cloud-sdk`

### Available Tools
- When you create git worktree, use `git wt`. How to use: `git-wt --help`
  - Add: `git wt <branch>` (create worktree/branch if needed), `git wt <branch> origin/main` (from start-point)
  - Remove: `git wt -d <branch>` (safe, only if merged), `git wt -D <branch>` (force)
  - Recent mise versions share trust across linked git worktrees. Trust the
    equivalent config in the repository's main checkout with `mise trust`; the
    worktree then inherits that trust automatically.
  - In paranoid mode, worktree trust sharing is disabled, so trust each config
    explicitly in the worktree.
- For browser automation, use `agent-browser` with the system `google-chrome-stable`.

