#!/usr/bin/env bash
set -euo pipefail

# Sync all SDK version strings from the VERSION file.
#
# Usage:
#   bash scripts/bump-version.sh              # read from VERSION file
#   bash scripts/bump-version.sh 0.4.0        # set a specific version
#
# Updates: VERSION, Verity.swift, Verity.kt, package.json, README.md

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -n "${1:-}" ]; then
    echo "$1" > "$REPO_DIR/VERSION"
fi

VERSION=$(cat "$REPO_DIR/VERSION" | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
    echo "ERROR: VERSION file is empty"
    exit 1
fi

echo "Syncing all version strings to $VERSION..."

# Swift SDK
VERITY_SWIFT="$REPO_DIR/sdks/swift/Sources/Verity/Verity.swift"
if [ -f "$VERITY_SWIFT" ]; then
    sed -i '' -E "s|public static let version = \".*\"|public static let version = \"$VERSION\"|" "$VERITY_SWIFT"
    echo "  Updated Verity.swift"
fi

# Kotlin SDK
VERITY_KT="$REPO_DIR/sdks/kotlin/src/main/kotlin/xyz/atheon/verity/Verity.kt"
if [ -f "$VERITY_KT" ]; then
    sed -i '' -E "s|const val VERSION = \".*\"|const val VERSION = \"$VERSION\"|" "$VERITY_KT"
    echo "  Updated Verity.kt"
fi

# JS SDK
PACKAGE_JSON="$REPO_DIR/sdks/js/package.json"
if [ -f "$PACKAGE_JSON" ]; then
    cd "$REPO_DIR/sdks/js"
    npm version "$VERSION" --no-git-tag-version --allow-same-version 2>/dev/null
    echo "  Updated package.json"
fi

# README install snippet
README="$REPO_DIR/README.md"
if [ -f "$README" ]; then
    sed -i '' -E "s|\.package\(url: \"https://github.com/atheonxyz/verity\", from: \".*\"\)|.package(url: \"https://github.com/atheonxyz/verity\", from: \"$VERSION\")|" "$README"
    echo "  Updated README.md"
fi

echo ""
echo "All versions set to $VERSION"
echo "Verify with: bash scripts/check-versions.sh"
