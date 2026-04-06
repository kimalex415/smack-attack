#!/bin/bash
# Usage: ./build-release.sh v1.0.4
set -e

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>  (e.g. $0 v1.0.5)"
  exit 1
fi

echo "Building smack-attack $VERSION..."

swiftc smack.swift -o smack-arm64   -target arm64-apple-macosx12.0
swiftc smack.swift -o smack-x86_64  -target x86_64-apple-macosx12.0

echo "Generating checksums..."
shasum -a 256 smack-arm64 smack-x86_64 > checksums.sha256
cat checksums.sha256

echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" smack-arm64 smack-x86_64 checksums.sha256 \
  --title "$VERSION" \
  --notes "Install:
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/kimalex415/smack-attack/main/install.sh | bash
\`\`\`"

echo "✅ Release $VERSION published."
