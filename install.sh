#!/bin/bash
set -e

REPO="kimalex415/smack-attack"
INSTALL_DIR="$HOME/.local/bin"
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

# Install to ~/.local/bin (no sudo needed)
mkdir -p "$INSTALL_DIR"
chmod +x /tmp/smack
mv /tmp/smack "$INSTALL_DIR/$BINARY_NAME"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  SHELL_RC="$HOME/.zshrc"
  [ -n "$BASH_VERSION" ] && SHELL_RC="$HOME/.bashrc"
  echo "" >> "$SHELL_RC"
  echo "# smack-attack" >> "$SHELL_RC"
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
  echo "   Added ~/.local/bin to PATH in $SHELL_RC"
  echo "   Run: source $SHELL_RC"
fi

echo ""
echo "✅ Smack Attack installed!"
echo "   Run 'smack start' to begin. Smack your MacBook to trigger the scream."
echo "   Run 'smack stop' to stop it."
