---
name: take-screenshot
description: Capture screenshots of the current work-in-progress UI via agent-browser against a running local dev server, then open them with google-chrome-stable. For UI changes, capture before/after pairs (and Figma reference shots when a design URL is provided) so visual diffs can be reviewed at a glance.
disable-model-invocation: true
---

# take-screenshot

Drive `agent-browser` to capture what the user is currently working on, save the PNG(s) to the scratchpad, and open them in `google-chrome-stable` for review.

## When to use

- The user asks to "screenshot", "撮影", "見せて", "before/after" the current change.
- After implementing a UI / frontend change that should be visually verified.
- The user shares a Figma URL and wants a side-by-side with the rendered UI.

## Output location

All PNGs go into the scratchpad directory (never the project tree):

```
<scratchpad>/take-screenshot-<short-timestamp>-<label>.png
```

Use labels like `before`, `after`, `figma`, `current` so the filenames are self-describing.

## Steps

### 1. Identify the dev server

- Look for a running local dev server first (`lsof -iTCP -sTCP:LISTEN -P -n | grep -E ':(3000|5173|4321|8080|8000)'` or similar). Reuse it if present.
- If none is running, start one in the background using whatever the project defines:
  - Prefer a project skill (e.g. a `/run` skill) when available.
  - Otherwise fall back to `npm run dev` / `pnpm dev` / `bun dev` / `yarn dev` / `cargo run` / `python -m http.server` etc. as appropriate.
  - Launch with `Bash(run_in_background=true)` and wait until the port responds (`curl -sI http://localhost:<port>` returns a response) before screenshotting.
- Record the URL of the page being worked on (the user's working route, not just `/`).

### 2. Decide what to capture

| Situation | Captures |
|-----------|----------|
| Pure UI change with reachable previous state (git stash / separate branch / deployed URL) | `before.png` + `after.png` |
| UI change without a clean "before" | `after.png` only — note this in the response |
| Figma URL supplied or referenced in the task | Additionally capture `figma.png` via the Figma MCP (`mcp__claude_ai_Figma__get_screenshot`) — never `agent-browser` against figma.com |
| Non-UI work (asked anyway) | A single `current.png` of the relevant page |

For before/after: stash or check out the prior state, screenshot, restore, re-run the dev server if it watches files, then screenshot the after. Be careful not to lose uncommitted work — prefer `git stash --keep-index` and always restore before reporting.

### 3. Capture

```bash
agent-browser open <URL>
agent-browser screenshot <path>            # viewport
agent-browser screenshot <path> --full-page # if a long page and full-page is supported
```

Reuse an existing `agent-browser` session — only call `agent-browser open` when the URL changes.

For Figma captures, always use the Figma MCP (`mcp__claude_ai_Figma__get_screenshot`, `get_design_context`, `get_metadata`, etc.). Do not point `agent-browser` at figma.com — the MCP returns the actual design surface, while a browser shot would capture the Figma editor chrome. If only a URL is given, extract the node-id from it and pass that to the MCP.

### 4. Open for review

Open all captured PNGs in one Chrome window (background, non-blocking):

```bash
google-chrome-stable <path1> <path2> ... &
```

Always use the system `google-chrome-stable` (per global instructions), never a Nix wrapper.

### 5. Report

Print, in order:

1. The dev-server URL used (and whether it was reused or freshly started).
2. The absolute path of each PNG with its label.
3. A one-line note on what to look at (e.g. "header spacing changed", "color token differs from Figma").

## Notes

- Do not write PNGs into the project tree — scratchpad only.
- If you started a dev server, leave it running unless the user asks otherwise; mention how to stop it.
- If the page requires auth or specific state, ask the user once how to reach it rather than guessing.
- For mobile/responsive checks, pass viewport flags to `agent-browser` (e.g. `--viewport 390x844`).
