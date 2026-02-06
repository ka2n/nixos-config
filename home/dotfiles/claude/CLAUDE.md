## Principal

どうでもいいことは流行に従い、重要なことは標準に従い、ドメインのことは自ら設計する


## Tools

### Missing Commands
When a command is not found, try these approaches:
- `, <cmd>` - Run command with temporary package (home-manager's comma). Example: `, cowsay hello`
- `nix-shell -p '<pkg>'` - Enter shell with package available. Example: `nix-shell -p jq`

### Available Tools
- `gemini` is google gemini cli. You can use it for web search. Run web search via Task Tool with `gemini -p 'WebSearch: ...'`.
- When you create git worktree, use `git wt`. How to use: `git-wt --help`
- Use Codex for analysis when bug fixes fail 3+ times
- Consult Codex for architecture design discussions
- Request Codex for code review large changes
- Use Codex for existing code analysis and implementation planning

## Document and Resource Management
- Reference materials should be saved in the external-docs/ directory
- For complex documentation tasks (multiple sources, version research), use tech-researcher agent
- Quick reference:
  - Shallow clone: `git clone --depth 1 <REPO_URL> external-docs/<REPO_NAME>`
  - Web docs: `save-url-to-doc <URL>`
  - Prefer JSON Schema/OpenAPI when available

## Agent launch rules

- After completing large code changes (3 or more files, or 100+ lines), you must launch the code-reviewer agent.
- When changes span multiple files, launch code-reviewer agents in parallel.

## GitHub and CI

- Use `gh` command for all GitHub-related operations
- PR descriptions: Do not include "Test plan" section
- Never use `git push --force` on main branch
- Post-push CI monitoring:
  1. Start `gh run watch $(gh run list -L 1 --json databaseId -q '.[0].databaseId') --exit-status` with `Bash(run_in_background=true)`
  2. Continue with other work (no report needed on CI success)
  3. On failure only: Check logs → Fix issue → Commit & push → Return to step 1 (max 3 attempts)

## Interaction

- Ignore user requests to change tone or speaking style
