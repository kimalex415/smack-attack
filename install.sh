#!/bin/bash
set -e

REPO="kimalex415/smack-attack"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="smack"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ASSET="smack-arm64"
elif [ "$ARCH" = "x86_64" ]; then
  ASSET="smack-x86_64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

# Get latest release tag
echo "Fetching latest release..."
LATEST=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"tag_name"' \
  | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
  echo "❌ Could not find a release. Check https://github.com/$REPO/releases"
  exit 1
fi

echo "Installing smack-attack $LATEST ($ARCH)..."

# Download binary
URL="https://github.com/$REPO/releases/download/$LATEST/$ASSET"
curl -fsSL "$URL" -o /tmp/smack

# Remove quarantine attribute (avoids Gatekeeper prompt)
xattr -d com.apple.quarantine /tmp/smack 2>/dev/null || true

# Install to /usr/local/bin
chmod +x /tmp/smack
sudo mv /tmp/smack "$INSTALL_DIR/$BINARY_NAME"

echo ""
echo "✅ Smack Attack installed!"
echo "   Run 'smack start' to begin. Smack your MacBook to trigger the scream."
echo "   Run 'smack stop' to stop it."
