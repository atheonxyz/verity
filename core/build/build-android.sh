#!/bin/bash
set -euo pipefail

# Build core libraries for Android (arm64-v8a + x86_64).
#
# Usage:
#   bash core/build/build-android.sh <provekit-path>
#   bash core/build/build-android.sh ../provekit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

ANDROID_ARM64="aarch64-linux-android"
ANDROID_X86="x86_64-linux-android"

if [ $# -lt 1 ]; then
    echo "Usage: bash core/build/build-android.sh <provekit-path>"
    exit 1
fi

PROVEKIT_ROOT="$(cd "$1" && pwd)"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

echo "=== Building Verity core for Android ==="
echo "Core dir:      $CORE_DIR"
echo "ProveKit root: $PROVEKIT_ROOT"

rustup target add "$ANDROID_ARM64" "$ANDROID_X86" 2>/dev/null || true

# Build provekit-ffi
pushd "$PROVEKIT_ROOT" > /dev/null
echo "Building provekit-ffi for $ANDROID_ARM64..."
cargo build --release --target "$ANDROID_ARM64" -p provekit-ffi
echo "Building provekit-ffi for $ANDROID_X86..."
cargo build --release --target "$ANDROID_X86" -p provekit-ffi
popd > /dev/null

# Build all core backends
pushd "$CORE_DIR" > /dev/null
echo "Building core backends for $ANDROID_ARM64..."
cargo build --release --target "$ANDROID_ARM64"
echo "Building core backends for $ANDROID_X86..."
cargo build --release --target "$ANDROID_X86"
popd > /dev/null

# Collect outputs
mkdir -p "$OUTPUT_DIR/arm64-v8a" "$OUTPUT_DIR/x86_64"

find "$PROVEKIT_ROOT/target/$ANDROID_ARM64/release" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/arm64-v8a/" \;
find "$CORE_DIR/target/$ANDROID_ARM64/release" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/arm64-v8a/" \;

find "$PROVEKIT_ROOT/target/$ANDROID_X86/release" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/x86_64/" \;
find "$CORE_DIR/target/$ANDROID_X86/release" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/x86_64/" \;

echo "=== Done: $OUTPUT_DIR ==="
