#!/bin/bash
set -e

# Ubuntu 25 System Setup Bootstrap Script
# This script installs Ansible and runs the main setup playbook

echo "======================================"
echo "Ubuntu 25 System Setup - Bootstrap"
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

# Run the main playbook
echo ""
echo "Running ansible-playbook setup.yml..."
echo ""
ansible-playbook setup.yml --ask-become-pass

echo ""
echo "======================================"
echo "Main Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. REBOOT your system (recommended)"
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
