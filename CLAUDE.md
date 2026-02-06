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

## Skills and Agents

- Skills: `home/dotfiles/claude/skills/<name>/SKILL.md`
- Agents: `home/dotfiles/claude/agents/<name>.md`
- To add skill to agent: add `skills: <skill-name>` in frontmatter
