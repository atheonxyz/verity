#!/bin/bash
set -euo pipefail

# Build core libraries for Android (arm64-v8a + x86_64).
#
# Usage:
#   bash core/build/build-android.sh [provekit-path] [--backends provekit|bb|all]
#
# If provekit-path is omitted, defaults to ./provekit at the repo root.
# If ProveKit is not found, it is cloned automatically and checked out to v1.
#
# Examples:
#   bash core/build/build-android.sh                         # Auto-detect / clone ProveKit
#   bash core/build/build-android.sh provekit                # Explicit path (repo root)
#   bash core/build/build-android.sh --backends provekit     # ProveKit only
#   bash core/build/build-android.sh --backends bb           # Barretenberg only
#   bash core/build/build-android.sh --backends all          # Both
#
# Environment:
#   ANDROID_NDK_HOME  — path to Android NDK (auto-detected if not set)
#   CARGO_PROFILE     — Cargo build profile (default: release)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

source "$REPO_DIR/scripts/ensure-provekit.sh"

# Parse arguments
_PROVEKIT_ARG=""
BACKENDS="provekit"

while [ $# -gt 0 ]; do
    case "$1" in
        --backends)
            BACKENDS="$2"
            shift 2
            ;;
        *)
            if [ -z "$_PROVEKIT_ARG" ]; then
                _PROVEKIT_ARG="$1"
            else
                echo "ERROR: Unknown argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

# Resolve ProveKit: use explicit arg, or default to $REPO_DIR/provekit (auto-clone if missing)
ensure_provekit "${_PROVEKIT_ARG:-$REPO_DIR/provekit}"

# Resolve backend flags
BUILD_PK=false
BUILD_BB=false
case "$BACKENDS" in
    provekit) BUILD_PK=true ;;
    bb)       BUILD_BB=true ;;
    all)      BUILD_PK=true; BUILD_BB=true ;;
    *)
        echo "ERROR: Invalid --backends value '$BACKENDS'. Use provekit, bb, or all."
        exit 1
        ;;
esac

CARGO_PROFILE="${CARGO_PROFILE:-release-mobile}"
export CARGO_PROFILE_RELEASE_MOBILE_DEBUG=0

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

PROVEKIT_BRANCH=$(git -C "$PROVEKIT_ROOT" rev-parse --abbrev-ref HEAD)
VERITY_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)

echo "=== Building Verity core for Android ==="
echo "Core dir:         $CORE_DIR"
echo "ProveKit root:    $PROVEKIT_ROOT"
echo "ProveKit branch:  $PROVEKIT_BRANCH ($(git -C "$PROVEKIT_ROOT" rev-parse --short HEAD))"
echo "Verity branch:    $VERITY_BRANCH ($(git -C "$REPO_DIR" rev-parse --short HEAD))"
echo "Backends:         $BACKENDS (pk=$BUILD_PK, bb=$BUILD_BB)"
echo "NDK:              $ANDROID_NDK_HOME"
echo "Cargo profile:    $CARGO_PROFILE"
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

# Clean previous output to avoid stale artifacts from different backend selections
rm -rf "$OUTPUT_DIR"

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

    RUST_TARGET_UPPER="$(echo "${RUST_TARGET//-/_}" | tr '[:lower:]' '[:upper:]')"
    RUST_TARGET_LOWER="$(echo "${RUST_TARGET//-/_}")"
    export "CC_${RUST_TARGET_UPPER}=$NDK_CC"
    export "AR_${RUST_TARGET_UPPER}=$NDK_AR"
    export "CARGO_TARGET_${RUST_TARGET_UPPER}_LINKER=$NDK_CC"
    export "CC_${RUST_TARGET_LOWER}=$NDK_CC"
    export "AR_${RUST_TARGET_LOWER}=$NDK_AR"
    unset CC AR 2>/dev/null || true

    # Build ProveKit FFI
    if $BUILD_PK; then
        pushd "$PROVEKIT_ROOT" > /dev/null
        echo "  Building provekit-ffi..."
        cargo build --profile "$CARGO_PROFILE" --target "$RUST_TARGET" -p provekit-ffi
        popd > /dev/null
    fi

    # Build Barretenberg FFI
    if $BUILD_BB; then
        pushd "$CORE_DIR" > /dev/null
        echo "  Building barretenberg-ffi..."
        cargo build --profile "$CARGO_PROFILE" --target "$RUST_TARGET" -p barretenberg-ffi
        popd > /dev/null
    fi

    # Collect outputs
    mkdir -p "$OUTPUT_DIR/$ABI"

    if $BUILD_PK; then
        find "$PROVEKIT_ROOT/target/$RUST_TARGET/$CARGO_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;
    fi
    if $BUILD_BB; then
        find "$CORE_DIR/target/$RUST_TARGET/$CARGO_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;
    fi

    echo "  -> $OUTPUT_DIR/$ABI/"
    echo ""
done

# Strip debug symbols and logs from all output libraries
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"
echo "Stripping debug symbols from Android libraries..."
for abi_dir in "$OUTPUT_DIR"/*/; do
    for lib in "$abi_dir"*.a "$abi_dir"*.so; do
        [ -f "$lib" ] || continue
        echo "  strip: $(basename "$lib") ($(basename "$abi_dir"))"
        "$LLVM_STRIP" --strip-debug --strip-unneeded "$lib"
    done
done

echo ""
echo "Library sizes:"
for abi_dir in "$OUTPUT_DIR"/*/; do
    for lib in "$abi_dir"*.a "$abi_dir"*.so; do
        [ -f "$lib" ] || continue
        ls -lh "$lib"
    done
done

echo "=== Done: $OUTPUT_DIR (backends: $BACKENDS) ==="
echo ""
echo "Next step: run sdks/kotlin/scripts/build-android.sh to compile JNI bridge + link libverity_jni.so"
