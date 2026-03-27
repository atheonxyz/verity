#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 0.1.0"
    exit 1
fi

AAR_DIR="$SDK_DIR/build/outputs/aar"
AAR_FILE="$AAR_DIR/verity-kotlin-release.aar"

if [ ! -f "$AAR_FILE" ]; then
    echo "ERROR: AAR not found at $AAR_FILE"
    echo "Run './gradlew :verity-kotlin:assembleRelease' first."
    exit 1
fi

TAG="v${VERSION}"
ASSET="verity-android-${VERSION}.aar"

echo "=== Releasing Verity Android v${VERSION} ==="

cp "$AAR_FILE" "$SDK_DIR/$ASSET"

echo ""
echo "Creating GitHub release $TAG ..."
gh release create "$TAG" \
    "$SDK_DIR/$ASSET" \
    --title "Verity Android $TAG" \
    --notes "Verity Android SDK $TAG — Kotlin/Android bindings for zero-knowledge proofs."

echo ""
echo "=== Done! ==="
echo ""
echo "Add to your project's build.gradle.kts:"
echo ""
echo "  dependencies {"
echo "      implementation(\"com.aspect:verity:${VERSION}\")"
echo "  }"

rm "$SDK_DIR/$ASSET"
