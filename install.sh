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

# Validate tag format to prevent injection
if ! echo "$LATEST" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "❌ Unexpected release tag format: $LATEST"
  exit 1
fi

echo "Installing smack-attack $LATEST ($ARCH)..."

# Use a secure temp file
TMP_BINARY=$(mktemp)
TMP_CHECKSUMS=$(mktemp)
trap 'rm -f "$TMP_BINARY" "$TMP_CHECKSUMS"' EXIT

# Download binary
BINARY_URL="https://github.com/$REPO/releases/download/$LATEST/$ASSET"
curl -fsSL "$BINARY_URL" -o "$TMP_BINARY"

# Verify checksum
CHECKSUMS_URL="https://github.com/$REPO/releases/download/$LATEST/checksums.sha256"
if curl -fsSL "$CHECKSUMS_URL" -o "$TMP_CHECKSUMS" 2>/dev/null; then
  echo "Verifying checksum..."
  EXPECTED=$(grep "$ASSET" "$TMP_CHECKSUMS" | awk '{print $1}')
  ACTUAL=$(shasum -a 256 "$TMP_BINARY" | awk '{print $1}')
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "❌ Checksum mismatch! Binary may be corrupted or tampered with."
    echo "   Expected: $EXPECTED"
    echo "   Got:      $ACTUAL"
    exit 1
  fi
  echo "✅ Checksum verified."
else
  echo "⚠️  No checksum file found for this release. Proceeding without verification."
fi

# Validate it's a real macOS binary
if ! file "$TMP_BINARY" | grep -q "Mach-O"; then
  echo "❌ Downloaded file is not a valid macOS binary."
  exit 1
fi

# Remove quarantine attribute (avoids Gatekeeper prompt on first run)
xattr -d com.apple.quarantine "$TMP_BINARY" 2>/dev/null || true

# Install to ~/.local/bin (no sudo needed)
mkdir -p "$INSTALL_DIR"
chmod +x "$TMP_BINARY"
cp "$TMP_BINARY" "$INSTALL_DIR/$BINARY_NAME"

# Add to PATH if not already configured
if ! grep -q 'local/bin' "${HOME}/.zshrc" 2>/dev/null && ! grep -q 'local/bin' "${HOME}/.bashrc" 2>/dev/null; then
  USER_SHELL=$(basename "$SHELL")
  if [ "$USER_SHELL" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi
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
