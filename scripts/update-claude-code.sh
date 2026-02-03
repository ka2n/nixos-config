#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_FILE="$SCRIPT_DIR/../pkgs/overrides/default.nix"

# Get latest version from npm registry
LATEST_VERSION=$(curl -s https://registry.npmjs.org/@anthropic-ai/claude-code | jq -r '.["dist-tags"].latest')

if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
    echo "Error: Failed to fetch latest version from npm registry" >&2
    exit 1
fi

# Get current version from default.nix
CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$OVERRIDE_FILE" | head -1)

echo "Current version: $CURRENT_VERSION"
echo "Latest version:  $LATEST_VERSION"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "Already up to date!"
    exit 0
fi

# Build download URL
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819"
DOWNLOAD_URL="$GCS_BUCKET/claude-code-releases/$LATEST_VERSION/linux-x64/claude"

echo "Fetching hash for: $DOWNLOAD_URL"

# Get SRI hash using nix-prefetch-url
HASH=$(nix-prefetch-url --type sha256 "$DOWNLOAD_URL" 2>/dev/null)
SRI_HASH=$(nix hash convert --hash-algo sha256 --to sri "$HASH")

echo "New hash: $SRI_HASH"

# Update default.nix
sed -i "s|version = \"$CURRENT_VERSION\"|version = \"$LATEST_VERSION\"|" "$OVERRIDE_FILE"
sed -i "s|/$CURRENT_VERSION/linux-x64/claude|/$LATEST_VERSION/linux-x64/claude|" "$OVERRIDE_FILE"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$SRI_HASH\"|" "$OVERRIDE_FILE"
sed -i "s|# claude-code $CURRENT_VERSION|# claude-code $LATEST_VERSION|" "$OVERRIDE_FILE"

echo "Updated $OVERRIDE_FILE"
echo ""
echo "Changes:"
grep -E '(version|url|hash)' "$OVERRIDE_FILE" | head -4
