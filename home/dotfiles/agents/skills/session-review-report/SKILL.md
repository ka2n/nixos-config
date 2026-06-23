---
name: session-review-report
description: Create an HTML report to review the current session's changes. Include screenshots when changes affect UI/visuals. Use when the user asks for a review report, session summary as HTML, or visual diff of changes.
disable-model-invocation: true
---

# session-review-report

Generate a self-contained HTML report summarizing the changes made during the current session, so the user can review them in a browser.

## Output

Write the report to the scratchpad directory:

```
<scratchpad>/session-review-<short-timestamp>.html
```

After writing, print the absolute path and (optionally) open it with `google-chrome-stable <path> &` in the background.

## Steps

1. Collect the change set:
   - `git status --short`
   - `git diff` (working tree + staged)
   - `git log --oneline <session-base>..HEAD` if commits were made
2. Decide whether the changes affect UI/visuals:
   - Touched files under frontend/UI paths (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, design tokens, theme configs)
   - User explicitly mentioned UI / visual / layout / style
3. If UI-affecting, capture screenshots:
   - Use the `screenshot-open` skill or invoke `agent-browser screenshot <path>` directly
   - Save PNGs into the same scratchpad directory next to the HTML, reference with relative `<img src="...">`
   - Capture before/after if a dev server / preview is available; otherwise just the current state
4. Build the HTML:
   - Single self-contained file (inline CSS, no external assets except local screenshots)
   - Sections: **Summary**, **Files changed**, **Diff** (syntax-highlighted with `<pre>`), **Screenshots** (only if captured), **Next steps / open questions**
   - Use a monospace font for code blocks and a readable max-width
5. Write the file with the `Write` tool, then print its path.

## Notes

- Do not commit the report; it lives in the scratchpad.
- Keep the HTML file < 2 MB; truncate very large diffs and link out instead.
- Skip the screenshot section entirely when no UI files were touched — do not fabricate placeholders.
