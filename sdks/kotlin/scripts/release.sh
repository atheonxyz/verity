#!/bin/bash
set -euo pipefail

# Publish the Kotlin SDK to Maven Central.
#
# Usage:
#   bash sdks/kotlin/scripts/release.sh [version]
#
# If version is omitted, reads from the VERSION file.
#
# Required environment variables:
#   GPG_SIGNING_KEY     — ASCII-armored GPG private key
#   GPG_PASSPHRASE      — passphrase for the key
#   SONATYPE_USERNAME   — Maven Central (Sonatype) username
#   SONATYPE_PASSWORD   — Maven Central (Sonatype) password

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SDK_DIR/../.." && pwd)"

VERSION="${1:-$(cat "$REPO_DIR/VERSION" | tr -d '[:space:]')}"
echo "Publishing xyz.atheon:verity:$VERSION to Maven Central"

# Validate environment
for var in GPG_SIGNING_KEY GPG_PASSPHRASE SONATYPE_USERNAME SONATYPE_PASSWORD; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: $var is not set"
        exit 1
    fi
done

# Verify the native libraries exist
if [ ! -d "$REPO_DIR/output/android/arm64-v8a" ]; then
    echo "ERROR: Android native libraries not found. Run 'make core-android' first."
    exit 1
fi

# Copy native libs into jniLibs
mkdir -p "$SDK_DIR/src/main/jniLibs/arm64-v8a" "$SDK_DIR/src/main/jniLibs/x86_64"
cp "$REPO_DIR/output/android/arm64-v8a/"*.so "$SDK_DIR/src/main/jniLibs/arm64-v8a/" 2>/dev/null || true
cp "$REPO_DIR/output/android/x86_64/"*.so "$SDK_DIR/src/main/jniLibs/x86_64/" 2>/dev/null || true

cd "$SDK_DIR"
./gradlew publish \
    -Pversion="$VERSION" \
    -Psigning.key="$GPG_SIGNING_KEY" \
    -Psigning.password="$GPG_PASSPHRASE" \
    -PsonatypeUsername="$SONATYPE_USERNAME" \
    -PsonatypePassword="$SONATYPE_PASSWORD"

echo "Published xyz.atheon:verity:$VERSION"
