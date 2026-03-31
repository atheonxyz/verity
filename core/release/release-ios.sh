#!/bin/bash
set -euo pipefail

# Prepare a Verity.xcframework release (zip + checksum + copy-pasteable gh command).
#
# Usage:
#   bash core/release/release-ios.sh          # reads VERSION file
#   bash core/release/release-ios.sh 0.3.0    # explicit version
#
# Requires: gh CLI authenticated, xcframework already built via make core-ios.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"
XCFW="$OUTPUT_DIR/Verity.xcframework"
ZIP="$OUTPUT_DIR/Verity.xcframework.zip"

VERSION="${1:-$(cat "$REPO_DIR/VERSION")}"
# Ensure v prefix for tag consistency (v0.2.0, not 0.2.0)
[[ "$VERSION" == v* ]] || VERSION="v$VERSION"

if [ ! -d "$XCFW" ]; then
    echo "ERROR: xcframework not found at $XCFW"
    echo "Build it first:"
    echo "  make core-ios PROVEKIT_PATH=../provekit"
    exit 1
fi

echo "=== Releasing $VERSION ==="

cd "$OUTPUT_DIR"
rm -f Verity.xcframework.zip
zip -r Verity.xcframework.zip Verity.xcframework

CHECKSUM=$(swift package compute-checksum "$ZIP")
echo "Checksum: $CHECKSUM"

REPO_URL=$(cd "$REPO_DIR" && gh repo view --json url -q .url 2>/dev/null || echo "https://github.com/atheonxyz/verity")
DOWNLOAD_URL="$REPO_URL/releases/download/$VERSION/Verity.xcframework.zip"

echo ""
echo "=== Ready to release $VERSION ==="
echo ""
echo "1. Create the GitHub release (copy & run):"
echo ""
echo "  gh release create $VERSION $ZIP \\"
echo "      --title \"$VERSION\" \\"
echo "      --notes \"Pre-built Verity xcframework with all backends\""
echo ""
echo "2. Then update sdks/swift/Package.swift with:"
echo ""
echo "  .binaryTarget("
echo "      name: \"VerityFFI\","
echo "      url: \"$DOWNLOAD_URL\","
echo "      checksum: \"$CHECKSUM\""
echo "  )"
