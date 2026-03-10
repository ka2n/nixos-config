---
name: save-url-to-doc
description: Save web documentation and external resources as markdown files for reference. Use when researching libraries/APIs ("read the documentation of X", "check the docs for Y"), after web searches to preserve useful pages, or when planning tasks that need external references. Saves to external-docs/ directory in the git repository root.
---
# save-url-to-doc

Save web page content as markdown to `external-docs/` for persistent reference.

## Usage

```bash
save-url-to-doc <URL>
```

Output: `$(git rev-parse --show-toplevel)/external-docs/<sanitized-url>.md`

## When to Use

- After WebSearch finds useful documentation
- Before implementing features that require external API/library docs
- When user asks to "read the documentation of..." or "check the docs for..."
- To preserve reference material for later use

## Workflow

1. Identify URL (from WebSearch results or user request)
2. Run `save-url-to-doc <URL>`
3. Read the saved file from `external-docs/` as needed

## Example

```bash
# Save React documentation
save-url-to-doc https://react.dev/reference/react/useState

# Output: Saved to: /path/to/repo/external-docs/react.dev_reference_react_useState.md
```

## Notes

- Prefer JSON Schema or OpenAPI spec files when available (download directly instead)
- Files are saved with sanitized URLs as filenames
- Content is extracted using readability algorithm (main content only)
