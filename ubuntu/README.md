# Ubuntu 25 System Configuration with Ansible

Ansible-based system configuration for Ubuntu 25 that mirrors the NixOS setup from `../nixos/`. This setup provides a complete desktop environment with Hyprland, development tools, and optional Microsoft enterprise integration (Intune + Defender ATP).

## Overview

This Ansible configuration automates the setup of:

- **Base System**: Core packages, locale (Asia/Tokyo, en_US.UTF-8, ja_JP.UTF-8), and system configuration
- **Hyprland Desktop**: Modern Wayland compositor with complete ecosystem (waybar, rofi, mako, etc.)
- **Desktop Applications**: Browsers (Chrome, Firefox, Edge), office (LibreOffice), media (VLC, Spotify), communication (Slack), note-taking (Obsidian)
- **Japanese Input**: fcitx5 with custom-built fcitx5-cskk (SKK input method)
- **Development Environment**: Go, Python, Node.js, Rust, Docker, mise, chezmoi, and modern CLI tools
- **Fonts**: Noto fonts (with CJK and emoji), Cica, JetBrains Mono Nerd Font
- **Security**: 1Password, GNOME Keyring
- **Enterprise** (optional): Microsoft Intune and Defender for Endpoint (mdatp)

## Prerequisites

1. **Fresh Ubuntu 25 Installation**
   - Minimal GNOME desktop installation via USB stick
   - User account created during installation

2. **Internet Connection**
   - Required for downloading packages and dependencies

3. **Sudo Access**
   - The script will prompt for your password when needed

## Quick Start

### 1. Initial Setup

After installing Ubuntu 25 with minimal GNOME:

```bash
# Clone this repository (or copy the ubuntu/ directory to your system)
cd /path/to/ubuntu

# Run the bootstrap script (installs Ansible and runs main setup)
./bootstrap.sh
```

The bootstrap script will:
1. Install Ansible from the official PPA
2. Run the main playbook (`setup.yml`)
3. Install and configure all desktop and development tools

### 2. Post-Installation

After the playbook completes:

```bash
# Reboot your system (recommended)
sudo reboot
```

After reboot:
1. Log in using the **ly** display manager
2. Select **Hyprland** as your session
3. Your Hyprland desktop environment will start

### 3. User Environment Configuration

Configure your user environment with the tools managed by aqua/mise/chezmoi:

```bash
# Initialize chezmoi for dotfiles management
chezmoi init

# Install development tools with mise
mise install

# Configure fcitx5 input method
fcitx5-configtool
# Add CSKK input method
# Set keyboard shortcut (e.g., Ctrl+Space) to switch input methods
```

### 4. Optional: Enterprise Tools

If you need Microsoft Intune and Defender ATP:

```bash
# Download WindowsDefenderATPOnboardingPackage.zip from Microsoft Defender Portal:
# Settings > Endpoints > Device management > Onboarding > Linux Server

# Run the enterprise playbook
ansible-playbook enterprise.yml --ask-become-pass \
  --extra-vars "mdatp_onboarding=/path/to/WindowsDefenderATPOnboardingPackage.zip"

# Reboot after installation
sudo reboot
```

## Directory Structure

```
ubuntu/
├── bootstrap.sh              # Bootstrap script (installs Ansible, runs setup)
├── ansible.cfg               # Ansible configuration (localhost mode)
├── setup.yml                 # Main playbook (desktop + development)
├── enterprise.yml            # Enterprise playbook (Intune + mdatp)
├── group_vars/
│   └── all.yml              # Global variables
└── roles/
    ├── base/                # Base system packages and configuration
    ├── hyprland/            # Hyprland desktop environment
    ├── apps/                # Desktop applications
    ├── japanese/            # fcitx5 + Japanese input method
    ├── development/         # Development tools and Docker
    ├── fonts/               # Font installation and configuration
    ├── security/            # 1Password, GNOME Keyring
    ├── intune/              # Microsoft Intune
    └── mdatp/               # Microsoft Defender for Endpoint
```

## Manual Execution

If you want more control, you can run Ansible manually:

### Install Ansible

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

### Run Main Setup

```bash
# Run all roles
ansible-playbook setup.yml --ask-become-pass

# Run specific roles with tags
ansible-playbook setup.yml --ask-become-pass --tags "base,hyprland"
ansible-playbook setup.yml --ask-become-pass --tags "development"
ansible-playbook setup.yml --ask-become-pass --tags "japanese"
```

### Run Enterprise Setup

```bash
# Install Intune only
ansible-playbook enterprise.yml --ask-become-pass --tags "intune"

# Install mdatp only (requires onboarding package)
ansible-playbook enterprise.yml --ask-become-pass --tags "mdatp" \
  --extra-vars "mdatp_onboarding=/path/to/WindowsDefenderATPOnboardingPackage.zip"

# Install both
ansible-playbook enterprise.yml --ask-become-pass \
  --extra-vars "mdatp_onboarding=/path/to/WindowsDefenderATPOnboardingPackage.zip"
```

## What Gets Installed

### Base System (Role: base)

**Core Packages:**
- Build tools: gcc, g++, make, cmake, pkg-config, autoconf, automake, libtool, bison
- Libraries: zlib, readline, libyaml, libffi, ncurses, gdbm, openssl, jemalloc
- Archive tools: unzip, p7zip
- CLI tools: wget, curl, tree, ripgrep, jq, fzf, fd, bat, lsd, colordiff, peco, gh (GitHub CLI)
- Terminal: tmux, kitty, alacritty
- Networking: NetworkManager, openssh-server
- System utilities: software-properties-common, ca-certificates, gnupg

**Configuration:**
- Timezone: Asia/Tokyo
- Locale: en_US.UTF-8 (default), ja_JP.UTF-8 (LC_CTYPE)
- Hostname: wk2511058
- User: k2 (added to groups: networkmanager, docker)

### Hyprland Desktop (Role: hyprland)

**Hyprland Installation:**
- Try PPA first: `ppa:hyprland-community/hyprland`
- Fallback: Build from source if PPA unavailable

**Hyprland Ecosystem:**
- Core: hyprland, hyprlock, hypridle, hyprpaper
- Status bar: waybar
- App launcher: rofi
- Notifications: mako
- Clipboard: wl-clipboard, cliphist
- Screenshots: grim, slurp, swappy
- Background: swaybg
- Display manager: ly

**XDG Desktop Portal:**
- xdg-desktop-portal-hyprland
- xdg-desktop-portal-gtk

**Tools:**
- nwg-displays (display configuration)
- nwg-look (GTK theme settings)
- dex (XDG autostart runner)

**Theming:**
- gnome-themes-extra (Adwaita)
- yaru-theme (GTK + icons)
- papirus-icon-theme

### Desktop Applications (Role: apps)

**Browsers:**
- Firefox
- Google Chrome
- Microsoft Edge

**Communication:**
- Slack

**Productivity:**
- Obsidian (note-taking)
- LibreOffice (office suite)

**File Management:**
- Thunar (with plugins: archive, media-tags, volman)

**Media:**
- VLC media player
- feh (image viewer)
- Spotify

**System Utilities:**
- Bluetooth: blueman, bluez
- Audio: pavucontrol, pulsemixer
- Tailscale (VPN)
- cameractrls (webcam settings)

**Input Tools:**
- xremap (key remapping)
- warpd (keyboard-driven mouse control)

**Additional:**
- just (task runner)
- yazi (terminal file manager)
- darkman (dark/light mode daemon)

### Japanese Input (Role: japanese)

**fcitx5 Base:**
- fcitx5 (input method framework)
- fcitx5-frontend-gtk2/3/4
- fcitx5-frontend-qt5
- fcitx5-module-wayland
- fcitx5-config-qt

**Custom Builds:**
- **libcskk** - Built from source (Rust-based SKK library)
- **fcitx5-cskk** - Built from source (fcitx5 plugin for SKK input)

**Dictionary:**
- SKK-JISYO.L (large Japanese dictionary)

**Configuration:**
- Environment variables set for GTK, Qt, Wayland
- Autostart enabled
- im-config configured for fcitx5

### Development Tools (Role: development)

**Programming Languages:**
- Go (golang-go)
- Python 3 (with pip, venv, dev packages)
- Node.js (with npm)
- Rust (via rustup)

**Version Managers:**
- mise (unified version manager)
- chezmoi (dotfiles manager)

**Editors:**
- Neovim (with vi/vim aliases)
- Fish shell

**Shell Enhancements:**
- Starship (prompt)
- Atuin (shell history)

**AI Development Tools:**
- claude-code
- codex
- gemini-cli

**Docker:**
- Docker CE (with buildx and compose plugins)
- User added to docker group

**Additional Tools:**
- Git, tig
- NoiseTorch (microphone noise suppression)
- just, ghq, yazi (via cargo/go)

### Fonts (Role: fonts)

**System Fonts:**
- Noto Sans, Noto Serif
- Noto Sans/Serif CJK (Japanese, Chinese, Korean)
- Noto Color Emoji
- Noto Sans Mono

**Developer Fonts:**
- JetBrains Mono Nerd Font (with icons)
- Cica (monospace font optimized for Japanese)

**Font Configuration:**
- Custom fontconfig with Japanese support
- Font priority: Cica (monospace), Noto (serif/sans), JetBrains Mono (fallback)

### Security (Role: security)

**GNOME Keyring:**
- gnome-keyring (credential storage)
- seahorse (GUI password manager)
- PAM integration for auto-unlock
- Autostart configuration

**1Password:**
- 1Password desktop app
- 1Password CLI
- Custom browser configuration (Zen Browser support)
- PolicyKit authentication agent

### Enterprise Tools (Roles: intune, mdatp)

**Microsoft Intune:**
- intune-portal package
- Microsoft repository configuration
- Reset script: `/usr/local/bin/reset-intune.sh`

**Microsoft Defender for Endpoint (mdatp):**
- Official installer script method
- Onboarding package support
- Health monitoring and connectivity testing
- Production channel (configurable)

**Requirements:**
- Ubuntu 22.04, 24.04, or 25 (uses 24.04 packages if needed)
- Internet connectivity to packages.microsoft.com
- Onboarding package for mdatp
- System reboot required after installation

## Configuration

### Global Variables

Edit `group_vars/all.yml` to customize:

```yaml
# User configuration
primary_user: k2
primary_user_groups:
  - networkmanager
  - docker

# Locale and timezone
timezone: Asia/Tokyo
locale: en_US.UTF-8
locale_ctype: ja_JP.UTF-8

# Hostname
hostname: wk2511058

# Hyprland
hyprland_ppa: "ppa:hyprland-community/hyprland"
hyprland_build_from_source: false

# Fonts
cica_font_version: "5.0.3"

# Japanese input
fcitx5_cskk_ref: "7ea513375d5412b37ab0251476f792d2467547e5"

# Microsoft Defender ATP
mdatp_channel: "prod"  # Options: prod, insiders-slow, insiders-fast
```

## Troubleshooting

### Ubuntu 25 (sudo-rs) Compatibility

Ubuntu 25 uses **sudo-rs** (Rust-based sudo replacement) instead of traditional sudo. Ansible's `become_ask_pass` has compatibility issues with sudo-rs.

**Workaround**: Set `ANSIBLE_BECOME_EXE` to use the original sudo wrapper:

```bash
export ANSIBLE_BECOME_EXE=sudo.ws
ansible-playbook setup.yml
```

Or add to your shell config (`~/.bashrc`):

```bash
export ANSIBLE_BECOME_EXE=sudo.ws
```

### Hyprland Installation Issues

If Hyprland PPA fails:
```bash
# The playbook will automatically attempt to build from source
# Check /tmp/hyprland-build/ for build logs
```

### Japanese Input Not Working

```bash
# Verify fcitx5 is running
ps aux | grep fcitx5

# Restart fcitx5
killall fcitx5
fcitx5 &

# Configure input methods
fcitx5-configtool
```

### Docker Permission Denied

```bash
# Log out and log back in after installation
# Or manually add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Microsoft Intune Issues

```bash
# Reset Intune enrollment
sudo /usr/local/bin/reset-intune.sh

# Reinstall if needed
sudo apt purge intune-portal
sudo apt install intune-portal
```

### Microsoft Defender ATP Issues

```bash
# Check health
sudo mdatp health

# Test connectivity
sudo mdatp connectivity test

# View logs
sudo journalctl -u mdatp

# Reinstall (download installer script first)
wget https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh
chmod +x mde_installer.sh
sudo ./mde_installer.sh --remove
# Then run enterprise.yml again with onboarding package
```

## Differences from NixOS Setup

### Not Included

Some packages from the NixOS setup are not included because they are managed by user-level tools:

- **User packages** (managed by aqua/mise):
  - Version-specific language runtimes
  - User-specific development tools

- **Custom packages requiring complex builds:**
  - inputactions-hyprland (Hyprland plugin)
  - Zen Browser (external flake dependency)

These can be installed manually or via user-level package managers after the main setup.

### Differences

1. **Package names**: Some packages have different names on Ubuntu vs NixOS
2. **Service management**: systemd units configured differently for Ubuntu
3. **Build from source**: Some packages may need to be built from source if not available in Ubuntu repos
4. **Updates**: Use `apt update && apt upgrade` instead of NixOS rebuild

## Updating the System

### System Updates

```bash
# Update all packages
sudo apt update && sudo apt upgrade

# Update specific roles
ansible-playbook setup.yml --ask-become-pass --tags "hyprland"
```

### Adding New Packages

Edit the appropriate role's `tasks/main.yml` file and re-run the playbook.

## Uninstallation

### Remove Enterprise Tools

```bash
# Remove Intune
sudo apt purge intune-portal

# Remove mdatp (download installer first)
wget https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh
chmod +x mde_installer.sh
sudo ./mde_installer.sh --remove
```

### Remove Hyprland

```bash
# If installed from PPA
sudo apt remove hyprland

# If built from source
sudo rm -rf /usr/local/bin/Hyprland
sudo rm -rf ~/.config/hypr
```

## Migration from NixOS

This setup is designed to be functionally equivalent to the NixOS configuration in `../nixos/`. The main differences are:

1. **Package Management**: apt instead of nix
2. **Configuration**: Ansible instead of Nix expressions
3. **Updates**: `apt upgrade` instead of `nixos-rebuild`
4. **User Environment**: Managed by chezmoi/mise instead of home-manager

Your dotfiles and user configuration should be identical when using chezmoi.

## Contributing

To add new packages or features:

1. Edit the appropriate role in `roles/`
2. Test the changes with `ansible-playbook setup.yml --check`
3. Run the playbook to apply changes
4. Update this README if needed

## References

- [Microsoft Intune for Ubuntu](https://learn.microsoft.com/en-us/intune/intune-service/user-help/microsoft-intune-app-linux)
- [Microsoft Defender for Endpoint - Ansible](https://learn.microsoft.com/en-us/defender-endpoint/linux-install-with-ansible)
- [Hyprland Documentation](https://wiki.hyprland.org/)
- [fcitx5 GitHub](https://github.com/fcitx/fcitx5)
- [fcitx5-cskk GitHub](https://github.com/fcitx/fcitx5-cskk)

## License

This configuration is based on the NixOS setup in `../nixos/` and maintains the same structure and intent.
