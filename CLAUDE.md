# NixOS Configuration

## Rebuild and Switch

- home-manager is also managed by NixOS, so `nixos-rebuild switch` is required
- `nh os` can also be used (recommended)
- Permission is only for testing builds (`nixos-rebuild build` or `nh os build`), not for switching

## Activation Scripts

- `coreutils` commands (`cat`, `mkdir`, `chmod`, `rm`, `tr`) are in PATH
- `sed`, `grep`, `openssl` etc. require full paths
- Define full paths in inner `let` block near usage

## SOPS Secrets

### Binary Format

- Encrypt plain text: `sops -e --input-type binary --output-type binary`
- Use `--filename-override` to match `.sops.yaml` rules when encrypting from stdin/temp file
- Use `format = "binary"` in module, decrypts to `/run/secrets/<name>` (tmpfs)

## herdr (terminal multiplexer)

- Binary is intentionally NOT nix-managed (see NOTE in `common/default.nix`):
  self-update (`herdr update`) and live session handoff conflict with immutable management
- `~/.config/herdr/config.toml` is NOT nix-managed either (Settings TUI writes to it,
  and herdr does not support config include/import). Instead, Nix ships
  `config.default.toml` alongside and seeds the real file once via activation (`herdrConfigSeed`)
- Workflow: edit the live config → mirror the change into `home/dotfiles/herdr/config.default.toml`
  and commit. Check drift with `diff ~/.config/herdr/config{,.default}.toml`
- Plugin `pane-petname` IS nix-managed (`home/dotfiles/herdr/plugins/`); its `herdr plugin link`
  registration is herdr-side state, run once manually per machine

## Gather (pkgs/gather)

- Windows/Electron app run via Wine. Requires `wineWow64Packages.full`
  (winegstreamer needed for camera; stable/waylandFull lack it)
- Graphics: X11/XWayland + DXVK. Wine's wayland driver renders a blank main window
- DXVK dlls come from the `dxvk.bin` output (x64/x32), not `out`
- Google SSO cannot complete under Wine — use password login
- Update: bump version + hash in `pkgs/gather/default.nix`

## Host notes (wk2511058, X1 Carbon Gen 13)

- `options iwlwifi disable_11be=1` in `hosts/wk2511058/configuration.nix` disables WiFi7
  client-side. The actual fix for WebRTC packet loss was disabling MLO on the AP
  (router: MLO off, WiFi7 on). Client counters all show 0% loss — don't trust ping/`iw` here
- Sudden poweroffs (BERT records, no kernel panic) are EC/firmware-level — a Lenovo support
  case, not an OS/config issue. Don't chase OS-side causes

## Skills and Agents

- Skills: `home/dotfiles/claude/skills/<name>/SKILL.md`
- Agents: `home/dotfiles/claude/agents/<name>.md`
- To add skill to agent: add `skills: <skill-name>` in frontmatter
