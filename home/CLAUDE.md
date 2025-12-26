# Home Manager

## Configuration Policy

Do not use `programs.<name>`. Instead, use:

- `xdg.configFile` - XDG-compliant config files (`~/.config/`)
- `home.packages` - Package installation
- `home.file` - Other dotfiles
