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
- If there is reference information, save it in the external-docs/ directory.
- When cloning external repositories, use shallow clones with clear naming: `git clone --depth 1 <REPO_URL> external-docs/<REPO_NAME>`
- For API documentation:
  - Prefer JSON Schema or OpenAPI spec files when available (download directly)
  - Otherwise, use `save-url-to-doc <URL>` to convert web docs to markdown

## Agent launch rules

- After completing large code changes (3 or more files, or 100+ lines), you must launch the code-reviewer agent.
- When changes span multiple files, launch code-reviewer agents in parallel.
