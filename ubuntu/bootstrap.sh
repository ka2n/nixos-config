#!/bin/bash
set -e

# Ubuntu 24.04 LTS System Setup Bootstrap Script
# This script installs Ansible and runs the main setup playbook

echo "======================================"
echo "Ubuntu 24.04 LTS System Setup - Bootstrap"
echo "======================================"
echo ""

# Check if running on Ubuntu
if [ ! -f /etc/os-release ]; then
    echo "Error: Cannot detect OS. /etc/os-release not found."
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    echo "Warning: This script is designed for Ubuntu. Detected OS: $ID"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Detected OS: $PRETTY_NAME"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root. It will prompt for sudo when needed."
    exit 1
fi

# Update package list
echo "Updating package list..."
sudo apt update

# Install basic tools required for setup
echo "Installing basic tools..."
sudo apt install -y curl git wget build-essential

# Install Ansible if not already installed
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    sudo apt install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
    echo "Ansible installed successfully."
else
    echo "Ansible is already installed: $(ansible --version | head -n 1)"
fi

echo ""

# Check if we're in the right directory
if [ ! -f "setup.yml" ]; then
    echo "Error: setup.yml not found in current directory."
    echo "Please run this script from the ubuntu/ directory."
    exit 1
fi

echo "======================================"
echo "Running Main Setup Playbook"
echo "======================================"
echo ""
echo "This will install:"
echo "  - Base system packages and configuration"
echo "  - Hyprland desktop environment"
echo "  - Desktop applications (browsers, office, media)"
echo "  - Japanese input (fcitx5 with custom builds)"
echo "  - Development tools and Docker"
echo "  - Fonts (Noto, Cica, Nerd Fonts)"
echo "  - Security tools (1Password, gnome-keyring)"
echo ""
read -p "Continue with setup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Add ~/.local/bin to PATH in .bashrc (at the top, before interactive check)
# This ensures PATH is available in both login shells and terminal emulators
if ! grep -q 'PATH=.*\.local/bin' ~/.bashrc; then
    echo "Adding ~/.local/bin to PATH in ~/.bashrc..."
    # Create temp file with PATH export at the top
    {
        echo '# Added by bootstrap.sh - ~/.local/bin for user-installed binaries'
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo ''
        cat ~/.bashrc
    } > ~/.bashrc.tmp
    mv ~/.bashrc.tmp ~/.bashrc
    echo "Added ~/.local/bin to PATH in ~/.bashrc"
else
    echo "~/.local/bin already in PATH"
fi

# Apply PATH change for current session
export PATH="$HOME/.local/bin:$PATH"

# Install Claude Code
echo ""
echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

# Run the main playbook
echo ""
echo "Running ansible-playbook setup.yml..."
echo ""

ansible-playbook setup.yml

echo ""
echo "======================================"
echo "Main Setup Complete!"
echo "======================================"
echo ""
echo "Installed:"
echo "  - Basic tools (curl, git, wget, build-essential)"
echo "  - Ansible and all playbook packages"
echo "  - Claude Code (run 'claude' to start)"
echo "  - ~/.local/bin added to PATH"
echo ""
echo "Next steps:"
echo ""
echo "1. REBOOT your system (recommended)"
echo "   Or run: source ~/.bashrc"
echo ""
echo "2. Optional: Install Microsoft Intune and Defender ATP"
echo "   Download WindowsDefenderATPOnboardingPackage.zip from Microsoft"
echo "   Then run:"
echo "   ansible-playbook enterprise.yml --ask-become-pass \\"
echo "     --extra-vars \"mdatp_onboarding=/path/to/WindowsDefenderATPOnboardingPackage.zip\""
echo ""
echo "3. Configure user environment with chezmoi:"
echo "   chezmoi init"
echo ""
echo "4. Set up version managers with mise:"
echo "   mise install"
echo ""
echo "======================================"
