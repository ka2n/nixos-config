# Home Manager

## Configuration Policy

Do not use `programs.<name>`. Instead, use:

- `xdg.configFile` - XDG-compliant config files (`~/.config/`)
- `home.packages` - Package installation
- `home.file` - Other dotfiles

## Best Practices

### Environment Variables and PATH

- Use `home.sessionPath` for PATH additions (not manual `export PATH=...` in shell configs)
- Use `home.sessionVariables` for environment variables
- These are automatically managed across all shells (bash, zsh, fish, etc.)

### Scripts Management

- Use `pkgs.writeShellScriptBin` for shell scripts in `home.packages`
- Store script source files in `home/dotfiles/local/bin/`
- Use `pkgs.replaceVars` to substitute package paths (e.g., `@git@` → `${pkgs.git}/bin/git`)
- Never inline long scripts - keep them in separate files for maintainability
- For scripts used only in one place, use `pkgs.writeShellScript` with local `let`:
  ```nix
  xdg.configFile."app/config".source = let
    helper-script = pkgs.writeShellScript "helper" (pkgs.replaceVars ./script.sh { ... });
  in pkgs.replaceVars ./config { script = "${helper-script}"; };
  ```

### Script Readability with `pkgs.replaceVars`

For better readability, assign placeholders to variables at the top of scripts:

```sh
#!/bin/sh
# Command paths (replaced by Nix)
git=@git@
jq=@jq@

# Use variables instead of @placeholder@
$git status | $jq -r '.foo'
```

This is more readable than: `@git@ status | @jq@ -r '.foo'`

### File Organization

- Keep dotfiles in `home/dotfiles/` directory
- Use `recursive = true` for multi-file configs
- Use `executable = true` for scripts when using `home.file`
- For templates, use `pkgs.replaceVars` instead of `pkgs.substituteAll`

### Package Management

**System vs User packages:**
- **System packages** (`common/default.nix`): Basic tools used system-wide
  - `coreutils`, `gawk`, `file`, `bubblewrap`
  - Development tools: `gcc`, `git`, `nodejs`
  - Networking tools: `curl`, `wget`
- **User packages** (`home/default.nix`): User-specific applications
  - Application-specific tools: `lf`, `chafa`, `imagemagick`
  - User preferences: text editors, GUI apps

### Sandboxing

Use `bubblewrap` for sandboxing untrusted operations (e.g., file previews):
- Mount only necessary directories (not entire `$HOME`)
- Use `--ro-bind` for read-only mounts
- Use `--unshare-net` to disable network access
- Example: lf previewer only accesses the current directory and cache
