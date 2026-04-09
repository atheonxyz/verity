#!/bin/bash
set -euo pipefail

# Build libverity_jni.so for Android (arm64-v8a + x86_64).
#
# Prerequisites:
#   1. Run core/build/build-android.sh first to compile the Rust crates.
#   2. Android NDK must be installed (set ANDROID_NDK_HOME or let auto-detect).
#
# Usage:
#   bash sdks/kotlin/scripts/build-android.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SDK_DIR/../.." && pwd)"
PROVEKIT_ROOT="${PROVEKIT_ROOT:-$(cd "$REPO_DIR/provekit" 2>/dev/null && pwd || echo "")}"
CORE_DIR="$REPO_DIR/core"
DISPATCHER_DIR="$CORE_DIR/dispatcher"
INCLUDE_DIR="$CORE_DIR/include"
JNI_DIR="$SDK_DIR/src/main/jni"
OUTPUT_DIR="$SDK_DIR/src/main/jniLibs"
CARGO_PROFILE="${CARGO_PROFILE:-release-mobile}"

# Android NDK — auto-detect or use env var
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

if [ ! -f "$JNI_DIR/verity_jni.c" ]; then
    echo "ERROR: Cannot find JNI bridge at $JNI_DIR/verity_jni.c"
    exit 1
fi

if [ ! -f "$DISPATCHER_DIR/verity_dispatch.c" ]; then
    echo "ERROR: Cannot find dispatch layer at $DISPATCHER_DIR/"
    exit 1
fi

echo "=== Building libverity_jni.so for Android ==="
echo "SDK dir:       $SDK_DIR"
echo "Core dir:      $CORE_DIR"
echo "NDK:           $ANDROID_NDK_HOME"
echo "Cargo profile: $CARGO_PROFILE"
if [ -n "$PROVEKIT_ROOT" ]; then
    echo "ProveKit root: $PROVEKIT_ROOT"
fi
echo ""

# NDK toolchain
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
if [ ! -d "$TOOLCHAIN" ]; then
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64"
fi
export PATH="$TOOLCHAIN/bin:$PATH"

API_LEVEL=24

TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "x86_64-linux-android:x86_64"
)

for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    ABI="${entry##*:}"

    echo "--- Building for $RUST_TARGET ($ABI) ---"

    case "$RUST_TARGET" in
        aarch64-linux-android) CC_PREFIX="aarch64-linux-android${API_LEVEL}" ;;
        x86_64-linux-android)  CC_PREFIX="x86_64-linux-android${API_LEVEL}" ;;
    esac

    CC="${TOOLCHAIN}/bin/${CC_PREFIX}-clang"
    AR="${TOOLCHAIN}/bin/llvm-ar"

    # Find static libraries from core build
    ANDROID_OUTPUT_DIR="$REPO_DIR/output/android/$ABI"
    CORE_TARGET_DIR="$CORE_DIR/target/$RUST_TARGET/$CARGO_PROFILE"
    PK_TARGET_DIR="${PROVEKIT_ROOT:+$PROVEKIT_ROOT/target/$RUST_TARGET/$CARGO_PROFILE}"

    if [ ! -d "$ANDROID_OUTPUT_DIR" ] && [ ! -d "$CORE_TARGET_DIR" ]; then
        echo "  WARNING: No build output found for $ABI"
        echo "  Run 'bash core/build/build-android.sh <provekit-path>' first."
        continue
    fi

    WORK_DIR=$(mktemp -d)

    # Detect which backends were built
    ANDROID_OUTPUT_DIR="$REPO_DIR/output/android/$ABI"
    HAS_PK=false
    HAS_BB=false
    [ -f "$ANDROID_OUTPUT_DIR/libprovekit_ffi.a" ] && HAS_PK=true
    [ -f "$ANDROID_OUTPUT_DIR/libbarretenberg_ffi.a" ] && HAS_BB=true
    echo "  Backends detected: pk=$HAS_PK, bb=$HAS_BB"

    # Compile dispatch layer
    echo "  Compiling dispatch layer..."
    "$CC" -c -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" -fPIC \
        "$DISPATCHER_DIR/verity_dispatch.c" -o "$WORK_DIR/verity_dispatch.o"

    BACKEND_OBJS=""
    if $HAS_PK; then
        "$CC" -c -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" -fPIC \
            "$DISPATCHER_DIR/backends/pk_backend.c" -o "$WORK_DIR/pk_backend.o"
        BACKEND_OBJS="$BACKEND_OBJS $WORK_DIR/pk_backend.o"
    fi
    if $HAS_BB; then
        "$CC" -c -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" -fPIC \
            "$DISPATCHER_DIR/backends/bb_backend.c" -o "$WORK_DIR/bb_backend.o"
        BACKEND_OBJS="$BACKEND_OBJS $WORK_DIR/bb_backend.o"
    fi

    # Compile JNI bridge
    echo "  Compiling JNI bridge..."
    "$CC" -c -I"$INCLUDE_DIR" -fPIC \
        "$JNI_DIR/verity_jni.c" -o "$WORK_DIR/verity_jni.o"

    # Collect static libraries from output/android/<ABI>/ (populated by build-android.sh)
    ANDROID_OUTPUT_DIR="$REPO_DIR/output/android/$ABI"
    LINK_LIBS=""

    if [ -d "$ANDROID_OUTPUT_DIR" ]; then
        for lib in "$ANDROID_OUTPUT_DIR"/lib*.a; do
            [ -f "$lib" ] || continue
            # Use --whole-archive for FFI crates to ensure constructor registration symbols are kept
            LINK_LIBS="$LINK_LIBS -Wl,--whole-archive $lib -Wl,--no-whole-archive"
        done
    fi

    # Dependent static libs from provekit build directory (lzma, zstd, blake3, ring)
    if [ -n "$PK_TARGET_DIR" ] && [ -d "$PK_TARGET_DIR/build" ]; then
        for lib in $(find "$PK_TARGET_DIR/build" -name "lib*.a" 2>/dev/null); do
            LINK_LIBS="$LINK_LIBS $lib"
        done
    fi

    if [ -z "$LINK_LIBS" ]; then
        echo "  WARNING: No static libraries found in $ANDROID_OUTPUT_DIR"
        echo "  Run 'make core-android' first."
        continue
    fi

    # Link into shared library
    echo "  Linking libverity_jni.so..."
    mkdir -p "$OUTPUT_DIR/$ABI"
    # --allow-multiple-definition: provekit-ffi and barretenberg static archives
    # both pull in overlapping low-level deps (blake3, lzma, etc.) that export
    # identical symbols. The first definition wins; both are from the same
    # upstream source at compatible versions.
    "$CC" -shared \
        -o "$OUTPUT_DIR/$ABI/libverity_jni.so" \
        -Wl,--allow-multiple-definition \
        "$WORK_DIR/verity_dispatch.o" \
        $BACKEND_OBJS \
        "$WORK_DIR/verity_jni.o" \
        $LINK_LIBS \
        -llog -lm -lc -lc++_static -lc++abi

    # Strip debug symbols to reduce .so size
    echo "  Stripping debug symbols..."
    "${TOOLCHAIN}/bin/llvm-strip" --strip-all "$OUTPUT_DIR/$ABI/libverity_jni.so"

    rm -rf "$WORK_DIR"
    echo "  -> $OUTPUT_DIR/$ABI/libverity_jni.so"
    echo ""
done

echo "=== Done! ==="
echo "Native libraries are in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*/libverity_jni.so 2>/dev/null || echo "No .so files found — check build output above."
