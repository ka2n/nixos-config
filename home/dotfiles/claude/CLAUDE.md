## Principal

どうでもいいことは流行に従い、重要なことは標準に従い、ドメインのことは自ら設計する


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
  - EnterWorktree / subagent `isolation: worktree` also go through `git wt` via the
    WorktreeCreate/WorktreeRemove hooks, which additionally run direnv and cleanup.
  - In paranoid mode, worktree trust sharing is disabled, so trust each config
    explicitly in the worktree.
- Use Codex for analysis when bug fixes fail 3+ times
- Consult Codex for architecture design discussions
- Request Codex for code review large changes
- Use Codex for existing code analysis and implementation planning

## Document and Resource Management
- Reference materials should be saved in the external-docs/ directory
- For complex documentation tasks (multiple sources, version research), use tech-researcher agent

- Use `obsidian-cli` skill to save project-external knowledge and work notes
- When creating notes in Obsidian, always include `agent` (harness name, e.g. claude-code) and `model` (model ID) properties in the frontmatter
- Quick reference:
  - Shallow clone: `git clone --depth 1 <REPO_URL> external-docs/<REPO_NAME>`
  - Web docs: `save-url-to-doc <URL>`
  - Prefer JSON Schema/OpenAPI when available

## Agent launch rules

- Delegate implementation (code editing) to subagents (e.g. `Agent(subagent_type: general-purpose, model: 'sonnet'|'opus')`)
  with concrete instructions: file paths, changes, verification commands, and any env caveats.
  The main session focuses on research, planning, judging review results, and reporting.
- When a subagent needs an isolated working copy (parallel edits, risky changes, or
  work that shouldn't touch the current tree), launch it with `isolation: worktree`
  from the start — don't create a worktree manually first. It goes through `git wt`
  via hooks, so the standard worktree layout and lifecycle hooks are applied
  automatically.
- Delegate branch creation / commit / push / PR creation to a subagent as well
  (pre-push hooks are slow; keep them out of the main context). Always launch these with
  `model: 'sonnet'` — it is mechanical work and doesn't need Opus. Spell out the branch
  name, commit message, PR title/body, files to stage, and constraints in the prompt.
  Multiple repos → parallel subagents.
- After completing large code changes (3 or more files, or 100+ lines), you must launch the code-reviewer agent.
- When changes span multiple files, launch code-reviewer agents in parallel.

## Git

- `git commit` / `git push` may print `.../mise/installs/ruby/...: symbol lookup error: ... GLIBC_PRIVATE`
  from git hooks. This is harmless noise (mise ruby × nix glibc mismatch); the operation itself succeeds.
  Judge success by exit code / `git log`, never retry because of this message.

## GitHub and CI

- Use `gh` command for all GitHub-related operations
- PR descriptions: Do not include "Test plan" section
- Never use `git push --force` on main branch
- Post-push CI monitoring:
  1. Start `gh run watch $(gh run list -L 1 --json databaseId -q '.[0].databaseId') --exit-status` with `Bash(run_in_background=true)`
  2. Continue with other work (no report needed on CI success)
  3. On failure only: Check logs → Fix issue → Commit & push → Return to step 1 (max 3 attempts)

## Browser

- agent-browser: always use system google-chrome-stable

@RTK.md
