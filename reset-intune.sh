#!/usr/bin/env bash
set -euo pipefail

echo "Killing intune-portal and identity-broker processes..."
pkill -9 -f intune-portal || true
pkill -9 -f microsoft-identity-broker || true

echo "Stopping microsoft-identity-device-broker service..."
sudo systemctl stop microsoft-identity-device-broker.service || true

echo "Clearing intune-portal data..."
rm -rf ~/.Microsoft ~/.cache/intune-portal ~/.config/intune ~/.local/share/intune-portal

echo "Clearing device-broker data..."
rm -rf ~/.config/microsoft-identity-broker
sudo rm -rf /var/lib/microsoft-identity-device-broker
rm -rf ~/.local/state/log/microsoft-identity-broker
rm -rf ~/.local/state/microsoft-identity-broker
mkdir -p ~/.config/microsoft-identity-broker
mkdir -p ~/.local/state/microsoft-identity-broker
mkdir -p ~/.local/state/log/microsoft-identity-broker

echo "Done. Intune and device-broker data have been reset."
echo "Run 'intune-portal' to start fresh."
