#!/bin/bash
set -euo pipefail

# Build core libraries for Android (arm64-v8a + x86_64).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

ANDROID_ARM64="aarch64-linux-android"
ANDROID_X86="x86_64-linux-android"

echo "=== Building Verity core for Android ==="

rustup target add "$ANDROID_ARM64" "$ANDROID_X86" 2>/dev/null || true

pushd "$CORE_DIR" > /dev/null
echo "Building for $ANDROID_ARM64..."
cargo build --release --target "$ANDROID_ARM64"
echo "Building for $ANDROID_X86..."
cargo build --release --target "$ANDROID_X86"
popd > /dev/null

mkdir -p "$OUTPUT_DIR/arm64-v8a" "$OUTPUT_DIR/x86_64"

find "$CORE_DIR/target/$ANDROID_ARM64/release" -maxdepth 1 -name "*.so" -exec cp {} "$OUTPUT_DIR/arm64-v8a/" \;
find "$CORE_DIR/target/$ANDROID_X86/release" -maxdepth 1 -name "*.so" -exec cp {} "$OUTPUT_DIR/x86_64/" \;

echo "=== Done: $OUTPUT_DIR ==="
