#!/bin/bash
set -euo pipefail

# Build core libraries for Android (arm64-v8a + x86_64).
#
# Usage:
#   bash core/build/build-android.sh <provekit-path>
#   bash core/build/build-android.sh ../provekit
#
# Environment:
#   ANDROID_NDK_HOME  — path to Android NDK (auto-detected if not set)
#   CARGO_PROFILE     — Cargo build profile (default: release)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

if [ $# -lt 1 ]; then
    echo "Usage: bash core/build/build-android.sh <provekit-path>"
    exit 1
fi

PROVEKIT_ROOT="$(cd "$1" && pwd)"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

CARGO_PROFILE="${CARGO_PROFILE:-release}"

# -- Android NDK detection --
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        ANDROID_NDK_HOME="$(ls -d "$HOME/Library/Android/sdk/ndk/"* 2>/dev/null | sort -V | tail -1)"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
        ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)"
    fi
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo "ERROR: Cannot find Android NDK. Set ANDROID_NDK_HOME."
    exit 1
fi

# NDK toolchain
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
if [ ! -d "$TOOLCHAIN" ]; then
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64"
fi

API_LEVEL=24

echo "=== Building Verity core for Android ==="
echo "Core dir:      $CORE_DIR"
echo "ProveKit root: $PROVEKIT_ROOT"
echo "NDK:           $ANDROID_NDK_HOME"
echo "Cargo profile: $CARGO_PROFILE"
echo ""

TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "x86_64-linux-android:x86_64"
)

# Ensure Rust targets installed
for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    rustup target add "$RUST_TARGET" 2>/dev/null || true
done

for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    ABI="${entry##*:}"

    echo "--- Building for $RUST_TARGET ($ABI) ---"

    # Set NDK cross-compiler for Cargo
    case "$RUST_TARGET" in
        aarch64-linux-android) CC_PREFIX="aarch64-linux-android${API_LEVEL}" ;;
        x86_64-linux-android)  CC_PREFIX="x86_64-linux-android${API_LEVEL}" ;;
    esac

    NDK_CC="${TOOLCHAIN}/bin/${CC_PREFIX}-clang"
    NDK_AR="${TOOLCHAIN}/bin/llvm-ar"

    # Cargo uses UPPER_UNDERSCORE for linker; cc-rs crate checks lowercase underscore forms
    RUST_TARGET_UPPER="$(echo "${RUST_TARGET//-/_}" | tr '[:lower:]' '[:upper:]')"
    RUST_TARGET_LOWER="$(echo "${RUST_TARGET//-/_}")"
    export "CC_${RUST_TARGET_UPPER}=$NDK_CC"
    export "AR_${RUST_TARGET_UPPER}=$NDK_AR"
    export "CARGO_TARGET_${RUST_TARGET_UPPER}_LINKER=$NDK_CC"
    export "CC_${RUST_TARGET_LOWER}=$NDK_CC"
    export "AR_${RUST_TARGET_LOWER}=$NDK_AR"
    # Do NOT set global CC/AR — it breaks host build-script compilation (e.g. ring crate)
    unset CC AR 2>/dev/null || true

    # Build provekit-ffi
    pushd "$PROVEKIT_ROOT" > /dev/null
    echo "  Building provekit-ffi..."
    cargo build --profile "$CARGO_PROFILE" --target "$RUST_TARGET" -p provekit-ffi
    popd > /dev/null

    # Build core backends
    pushd "$CORE_DIR" > /dev/null
    echo "  Building core backends..."
    cargo build --profile "$CARGO_PROFILE" --target "$RUST_TARGET"
    popd > /dev/null

    # Collect outputs
    mkdir -p "$OUTPUT_DIR/$ABI"

    find "$PROVEKIT_ROOT/target/$RUST_TARGET/$CARGO_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;
    find "$CORE_DIR/target/$RUST_TARGET/$CARGO_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;

    echo "  -> $OUTPUT_DIR/$ABI/"
    echo ""
done

echo "=== Done: $OUTPUT_DIR ==="
echo ""
echo "Next step: run sdks/kotlin/scripts/build-android.sh to compile JNI bridge + link libverity_jni.so"
