#!/usr/bin/env bash
set -euo pipefail

echo "🚀 New Project Setup"
echo

# Get project directory
read -p "Project directory (default: current directory): " project_dir
project_dir=${project_dir:-.}

# Create directory if it doesn't exist
if [ "$project_dir" != "." ]; then
  mkdir -p "$project_dir"
fi

# Navigate to project directory
cd "$project_dir"

# Check if flake.nix already exists
if [ -f "flake.nix" ]; then
  echo "⚠️  flake.nix already exists in this directory."
  read -p "Overwrite? (y/N): " overwrite
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Initialize template
echo
echo "📦 Initializing template from ~/nixos-config..."
nix flake init -t ~/nixos-config

# Allow direnv
if command -v direnv &> /dev/null; then
  echo
  echo "✅ Allowing direnv..."
  direnv allow
  echo
  echo "🎉 Done! The development environment is now active."
else
  echo
  echo "⚠️  direnv not found. You can manually activate the environment with:"
  echo "   nix develop"
fi

echo
echo "📖 See README.md for customization options."
