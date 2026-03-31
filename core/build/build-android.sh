#!/bin/bash
set -euo pipefail

#
# Usage:
#   bash core/build/build-android.sh <provekit-path>
#   bash core/build/build-android.sh ../provekit
#
# ProveKit branch: v1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-24}"

SELECTED_ABIS="${VERITY_ANDROID_ABIS:-arm64-v8a}"

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
echo "Android ABIs:  $SELECTED_ABIS"

if [ -n "${ANDROID_NDK_HOME:-}" ]; then
    NDK_ROOT="$ANDROID_NDK_HOME"
elif [ -n "${ANDROID_NDK_ROOT:-}" ]; then
    NDK_ROOT="$ANDROID_NDK_ROOT"
elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    NDK_ROOT="$(ls -d "$HOME/Library/Android/sdk/ndk"/* 2>/dev/null | sort -V | tail -n 1)"
elif [ -d "$HOME/Library/Android/sdk/ndk-bundle" ]; then
    NDK_ROOT="$HOME/Library/Android/sdk/ndk-bundle"
else
    echo "ERROR: Android NDK not found. Set ANDROID_NDK_HOME or install the NDK under ~/Library/Android/sdk/ndk."
    exit 1
fi

HOST_TAG="darwin-$(uname -m)"
TOOLCHAIN_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin"

if [ ! -d "$TOOLCHAIN_BIN" ]; then
    ALT_PREBUILT="$(ls -d "$NDK_ROOT/toolchains/llvm/prebuilt"/darwin-* 2>/dev/null | head -n 1)"
    if [ -n "$ALT_PREBUILT" ]; then
        TOOLCHAIN_BIN="$ALT_PREBUILT/bin"
    else
        echo "ERROR: Android NDK LLVM toolchain not found at $TOOLCHAIN_BIN"
        exit 1
    fi
fi

echo "Android NDK:  $NDK_ROOT"
echo "Toolchain:    $TOOLCHAIN_BIN"

CARGO_PROFILE="${CARGO_PROFILE:-release-mobile}"
PROVEKIT_PROFILE="${PROVEKIT_PROFILE:-$CARGO_PROFILE}"
export CARGO_PROFILE_RELEASE_MOBILE_DEBUG=0
echo "Using cargo profile: $CARGO_PROFILE (core), $PROVEKIT_PROFILE (provekit)"
echo "release-mobile debug info: disabled"

TARGETS=()
OUTPUT_ABIS=()

IFS=',' read -r -a ABI_LIST <<< "$SELECTED_ABIS"
for ABI in "${ABI_LIST[@]}"; do
    case "$ABI" in
        arm64-v8a)
            TARGETS+=("aarch64-linux-android")
            OUTPUT_ABIS+=("arm64-v8a")
            ;;
        x86_64)
            TARGETS+=("x86_64-linux-android")
            OUTPUT_ABIS+=("x86_64")
            ;;
        *)
            echo "ERROR: Unsupported Android ABI '$ABI'"
            exit 1
            ;;
    esac
done

rustup target add "${TARGETS[@]}" 2>/dev/null || true

toolchain_prefix_for_target() {
    case "$1" in
        aarch64-linux-android) printf '%s' "aarch64-linux-android${ANDROID_API_LEVEL}" ;;
        x86_64-linux-android) printf '%s' "x86_64-linux-android${ANDROID_API_LEVEL}" ;;
        *) return 1 ;;
    esac
}

# Build provekit-ffi as cdylib (.so) for Android
# Create a timestamp marker so we can distinguish freshly built artifacts from
# stale ones left over by previous builds.
BUILD_MARKER="$(mktemp)"
pushd "$PROVEKIT_ROOT" > /dev/null
for TARGET in "${TARGETS[@]}"; do
    TOOLCHAIN_PREFIX="$(toolchain_prefix_for_target "$TARGET")"
    TARGET_ENV_NAME="${TARGET//-/_}"
    TARGET_ENV_NAME="$(printf '%s' "$TARGET_ENV_NAME" | tr '[:lower:]' '[:upper:]')"
    echo "Building provekit-ffi (cdylib) for $TARGET..."
    env \
        "CC_${TARGET//-/_}=$TOOLCHAIN_BIN/$TOOLCHAIN_PREFIX-clang" \
        "CXX_${TARGET//-/_}=$TOOLCHAIN_BIN/$TOOLCHAIN_PREFIX-clang++" \
        "AR_${TARGET//-/_}=$TOOLCHAIN_BIN/llvm-ar" \
        "CARGO_TARGET_${TARGET_ENV_NAME}_LINKER=$TOOLCHAIN_BIN/$TOOLCHAIN_PREFIX-clang" \
        cargo rustc --profile "$PROVEKIT_PROFILE" --target "$TARGET" -p provekit-ffi -- --crate-type=cdylib
done
popd > /dev/null

for ABI in "${OUTPUT_ABIS[@]}"; do
    mkdir -p "$OUTPUT_DIR/$ABI"
done

for INDEX in "${!TARGETS[@]}"; do
    TARGET="${TARGETS[$INDEX]}"
    ABI="${OUTPUT_ABIS[$INDEX]}"
    # Use -newer to only match artifacts produced by this build, avoiding stale
    # outputs from previous runs that may linger in the deps/ directory.
    SO_SOURCE="$(find "$PROVEKIT_ROOT/target/$TARGET/$PROVEKIT_PROFILE" -path '*/deps/libprovekit_ffi-*.so' -type f -newer "$BUILD_MARKER" | head -n 1)"

    if [ -z "$SO_SOURCE" ]; then
        echo "ERROR: Could not find freshly built provekit_ffi shared library for $TARGET"
        exit 1
    fi

    cp "$SO_SOURCE" "$OUTPUT_DIR/$ABI/libprovekit_ffi.so"

    if [ -x "$TOOLCHAIN_BIN/llvm-strip" ]; then
        find "$OUTPUT_DIR/$ABI" -maxdepth 1 -name "*.so" -exec "$TOOLCHAIN_BIN/llvm-strip" -s {} \;
    fi
done
rm -f "$BUILD_MARKER"

echo ""
echo "Output sizes:"
for ABI in "${OUTPUT_ABIS[@]}"; do
    ls -lh "$OUTPUT_DIR/$ABI/"*.so 2>/dev/null || echo "  (no .so files for $ABI)"
done

echo "=== Done: $OUTPUT_DIR ==="
