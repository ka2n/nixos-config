---
name: screenshot-open
description: Take a screenshot with agent-browser and open it with google-chrome-stable. Use when the user wants to capture and view a web page screenshot.
disable-model-invocation: true
---

# screenshot-open

Capture a screenshot of the current `agent-browser` page (or a given URL) and open the resulting PNG with `google-chrome-stable`.

## Steps

1. Pick an output path in the scratchpad directory, e.g.
   `<scratchpad>/screenshot-<short-timestamp>.png`
2. If the user provided a URL, navigate first:
   ```bash
   agent-browser open <URL>
   ```
3. Take the screenshot:
   ```bash
   agent-browser screenshot <path>
   ```
4. Open it in Chrome (background, do not block):
   ```bash
   google-chrome-stable <path> &
   ```
5. Print the absolute path of the PNG.

## Notes

- Always use the system `google-chrome-stable` (per global instructions), not a Nix wrapper.
- Reuse the existing agent-browser session if one is already open — only call `agent-browser open` when a URL is explicitly requested.
- For full-page captures, pass `--full-page` to `agent-browser screenshot` when supported.
- The screenshot file lives in the scratchpad; do not write it into the project tree.
