#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$SDK_DIR/output"
XCFW="$OUTPUT_DIR/Verity.xcframework"
ZIP="$OUTPUT_DIR/Verity.xcframework.zip"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: bash scripts/release.sh <version>"
    echo "Example: bash scripts/release.sh v0.2.0"
    exit 1
fi

if [ ! -d "$XCFW" ]; then
    echo "ERROR: xcframework not found at $XCFW"
    echo "Run 'bash scripts/build-xcframework.sh <provekit-path> <zk-ffi-path>' first."
    exit 1
fi

echo "=== Releasing $VERSION ==="

# Zip
echo "Zipping xcframework..."
cd "$OUTPUT_DIR"
rm -f Verity.xcframework.zip
zip -r Verity.xcframework.zip Verity.xcframework

# Checksum
echo ""
CHECKSUM=$(swift package compute-checksum "$ZIP")
echo "Checksum: $CHECKSUM"

# Upload
echo ""
echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" "$ZIP" \
    --title "$VERSION" \
    --notes "Pre-built Verity xcframework with all backends"

# Show what to update
REPO_URL=$(cd "$SDK_DIR" && gh repo view --json url -q .url 2>/dev/null || echo "https://github.com/atheonxyz/verity")
DOWNLOAD_URL="$REPO_URL/releases/download/$VERSION/Verity.xcframework.zip"

echo ""
echo "=== Done! ==="
echo ""
echo "Update Package.swift with:"
echo ""
echo "  .binaryTarget("
echo "      name: \"VerityFFI\","
echo "      url: \"$DOWNLOAD_URL\","
echo "      checksum: \"$CHECKSUM\""
echo "  )"
echo ""

# Clean up
rm -f "$ZIP"
