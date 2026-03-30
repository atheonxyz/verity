#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SDK_DIR/../.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"
XCFW="$OUTPUT_DIR/Verity.xcframework"
ZIP="$OUTPUT_DIR/Verity.xcframework.zip"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(cat "$REPO_DIR/VERSION")
    VERSION="v$VERSION"
fi

if [ ! -d "$XCFW" ]; then
    echo "ERROR: xcframework not found at $XCFW"
    echo "Run 'make core-ios' first."
    exit 1
fi

echo "=== Releasing $VERSION ==="

cd "$OUTPUT_DIR"
rm -f Verity.xcframework.zip
zip -r Verity.xcframework.zip Verity.xcframework

CHECKSUM=$(swift package compute-checksum "$ZIP")
echo "Checksum: $CHECKSUM"

echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" "$ZIP" \
    --title "$VERSION" \
    --notes "Pre-built Verity xcframework with all backends"

REPO_URL=$(cd "$REPO_DIR" && gh repo view --json url -q .url 2>/dev/null || echo "https://github.com/atheonxyz/verity")
DOWNLOAD_URL="$REPO_URL/releases/download/$VERSION/Verity.xcframework.zip"

echo ""
echo "=== Done! ==="
echo ""
echo "Update sdks/swift/Package.swift with:"
echo ""
echo "  .binaryTarget("
echo "      name: \"VerityFFI\","
echo "      url: \"$DOWNLOAD_URL\","
echo "      checksum: \"$CHECKSUM\""
echo "  )"

rm -f "$ZIP"
