## Document and Resource Management
- Reference materials should be saved in the external-docs/ directory
- For complex documentation tasks (multiple sources, version research), use tech-researcher agent

- Use `obsidian-cli` skill to save project-external knowledge and work notes
- When creating notes in Obsidian, always include `agent` (harness name, e.g. claude-code) and `model` (model ID) properties in the frontmatter
- Quick reference:
  - Shallow clone: `git clone --depth 1 <REPO_URL> external-docs/<REPO_NAME>`
  - Web docs: `save-url-to-doc <URL>`
  - Prefer JSON Schema/OpenAPI when available

