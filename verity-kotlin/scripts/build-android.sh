#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROVEKIT_ROOT="${PROVEKIT_ROOT:-$(cd "$SDK_DIR/../provekit" && pwd)}"
BB_FFI_DIR="${BB_FFI_ROOT:-$(cd "$SDK_DIR/../zkffi" && pwd)}"
# Use the new handle-based dispatch layer from the repo's Sources directory
VERITY_DISPATCH_DIR="${VERITY_DISPATCH_DIR:-$(cd "$SDK_DIR/../Sources/VerityDispatch" && pwd)}"
VERITY_INCLUDE="$VERITY_DISPATCH_DIR/include"
OUTPUT_DIR="$SDK_DIR/src/main/jniLibs"

# Android NDK — set ANDROID_NDK_HOME or let the script find it
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        ANDROID_NDK_HOME="$(ls -d "$HOME/Library/Android/sdk/ndk/"* 2>/dev/null | sort -V | tail -1)"
    elif [ -d "$ANDROID_HOME/ndk" ]; then
        ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)"
    fi
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo "ERROR: Cannot find Android NDK. Set ANDROID_NDK_HOME."
    exit 1
fi

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    echo "Set PROVEKIT_ROOT env var to the provekit repo path."
    exit 1
fi

if [ ! -f "$BB_FFI_DIR/Cargo.toml" ]; then
    echo "ERROR: Cannot find zkffi workspace at $BB_FFI_DIR"
    echo "Set BB_FFI_ROOT env var to the zkffi workspace path."
    exit 1
fi

echo "=== Building Verity Android native libraries ==="
echo "SDK dir:       $SDK_DIR"
echo "ProveKit root: $PROVEKIT_ROOT"
echo "BB FFI dir:    $BB_FFI_DIR"
echo "Dispatch dir:  $VERITY_DISPATCH_DIR"
echo "NDK:           $ANDROID_NDK_HOME"
echo ""

# Android targets
TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "x86_64-linux-android:x86_64"
)

# Ensure Rust targets are installed
for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    rustup target add "$RUST_TARGET" 2>/dev/null || true
done

# NDK toolchain
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
if [ ! -d "$TOOLCHAIN" ]; then
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64"
fi

export PATH="$TOOLCHAIN/bin:$PATH"

API_LEVEL=24

for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    ABI="${entry##*:}"

    echo "--- Building for $RUST_TARGET ($ABI) ---"

    # Determine the NDK compiler prefix
    case "$RUST_TARGET" in
        aarch64-linux-android)  CC_PREFIX="aarch64-linux-android${API_LEVEL}" ;;
        x86_64-linux-android)   CC_PREFIX="x86_64-linux-android${API_LEVEL}" ;;
    esac

    RUST_TARGET_UPPER="$(echo "${RUST_TARGET//-/_}" | tr '[:lower:]' '[:upper:]')"
    export "CC_${RUST_TARGET_UPPER}=${TOOLCHAIN}/bin/${CC_PREFIX}-clang"
    export "AR_${RUST_TARGET_UPPER}=${TOOLCHAIN}/bin/llvm-ar"
    export "CARGO_TARGET_${RUST_TARGET_UPPER}_LINKER=${TOOLCHAIN}/bin/${CC_PREFIX}-clang"

    # Build provekit-ffi
    pushd "$PROVEKIT_ROOT" > /dev/null
    echo "  Building provekit-ffi..."
    cargo build --release --target "$RUST_TARGET" -p provekit-ffi
    popd > /dev/null

    # Build barretenberg-ffi
    pushd "$BB_FFI_DIR" > /dev/null
    echo "  Building barretenberg-ffi..."
    cargo build --release --target "$RUST_TARGET"
    popd > /dev/null

    # Compile dispatch layer (vtable + backend registrations) + JNI bridge
    echo "  Compiling dispatch layer + JNI bridge..."
    WORK_DIR=$(mktemp -d)

    "${TOOLCHAIN}/bin/${CC_PREFIX}-clang" -c \
        -I"$VERITY_DISPATCH_DIR" \
        -I"$VERITY_INCLUDE" \
        -fPIC \
        "$VERITY_DISPATCH_DIR/verity_dispatch.c" \
        -o "$WORK_DIR/verity_dispatch.o"

    "${TOOLCHAIN}/bin/${CC_PREFIX}-clang" -c \
        -I"$VERITY_DISPATCH_DIR" \
        -I"$VERITY_INCLUDE" \
        -fPIC \
        "$VERITY_DISPATCH_DIR/pk_backend.c" \
        -o "$WORK_DIR/pk_backend.o"

    "${TOOLCHAIN}/bin/${CC_PREFIX}-clang" -c \
        -I"$VERITY_DISPATCH_DIR" \
        -I"$VERITY_INCLUDE" \
        -fPIC \
        "$VERITY_DISPATCH_DIR/bb_backend.c" \
        -o "$WORK_DIR/bb_backend.o"

    # jni.h is provided by the NDK sysroot (included automatically by the NDK clang)
    "${TOOLCHAIN}/bin/${CC_PREFIX}-clang" -c \
        -I"$VERITY_INCLUDE" \
        -fPIC \
        "$SDK_DIR/src/main/jni/verity_jni.c" \
        -o "$WORK_DIR/verity_jni.o"

    # Link into shared library
    echo "  Linking libverity_jni.so..."
    mkdir -p "$OUTPUT_DIR/$ABI"
    "${TOOLCHAIN}/bin/${CC_PREFIX}-clang" -shared \
        -o "$OUTPUT_DIR/$ABI/libverity_jni.so" \
        -Wl,--allow-multiple-definition \
        "$WORK_DIR/verity_dispatch.o" \
        "$WORK_DIR/pk_backend.o" \
        "$WORK_DIR/bb_backend.o" \
        "$WORK_DIR/verity_jni.o" \
        -Wl,--whole-archive \
        "$PROVEKIT_ROOT/target/$RUST_TARGET/release/libprovekit_ffi.a" \
        -Wl,--no-whole-archive \
        "$BB_FFI_DIR/target/$RUST_TARGET/release/libbarretenberg_ffi.a" \
        "$BB_FFI_DIR/target/$RUST_TARGET/release/build/bb-"*/out/bb/$RUST_TARGET/lib/libbarretenberg.a \
        "$PROVEKIT_ROOT/target/$RUST_TARGET/release/build/lzma-sys-"*/out/liblzma.a \
        "$PROVEKIT_ROOT/target/$RUST_TARGET/release/build/zstd-sys-"*/out/libzstd.a \
        $(find "$PROVEKIT_ROOT/target/$RUST_TARGET/release/build/" -path "*/blake3-*/out/libblake3*.a" 2>/dev/null) \
        -llog -lm -lc -lc++_static -lc++abi

    rm -rf "$WORK_DIR"
    echo "  -> $OUTPUT_DIR/$ABI/libverity_jni.so"
    echo ""
done

echo "=== Done! ==="
echo "Native libraries are in: $OUTPUT_DIR"
echo ""
echo "ABIs built:"
for entry in "${TARGETS[@]}"; do
    ABI="${entry##*:}"
    echo "  - $ABI"
done
