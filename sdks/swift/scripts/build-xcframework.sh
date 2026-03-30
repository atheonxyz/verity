#!/bin/bash
set -euo pipefail

# Usage:
#   bash scripts/build-xcframework.sh <provekit-path>
#   bash scripts/build-xcframework.sh ../provekit
#
# The zk-ffi backends are now bundled in the zkffi/ directory of this repo.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$SDK_DIR/output"
ZK_FFI_DIR="$SDK_DIR/zkffi"

IOS_DEVICE="aarch64-apple-ios"
IOS_SIM="aarch64-apple-ios-sim"

if [ $# -lt 1 ]; then
    echo "Usage: bash scripts/build-xcframework.sh <provekit-path>"
    echo ""
    echo "Example:"
    echo "  bash scripts/build-xcframework.sh ../provekit"
    exit 1
fi

PROVEKIT_ROOT="$(cd "$1" && pwd)"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

if [ ! -f "$ZK_FFI_DIR/Cargo.toml" ]; then
    echo "ERROR: Cannot find zkffi workspace at $ZK_FFI_DIR"
    exit 1
fi

echo "=== Building Verity xcframework ==="
echo "SDK dir:       $SDK_DIR"
echo "ProveKit root: $PROVEKIT_ROOT"
echo "zkffi dir:     $ZK_FFI_DIR"
echo ""

rustup target add "$IOS_DEVICE" "$IOS_SIM" 2>/dev/null || true

# --- Build provekit-ffi ---
pushd "$PROVEKIT_ROOT" > /dev/null

echo "Building provekit-ffi for $IOS_DEVICE..."
cargo build --release --target "$IOS_DEVICE" -p provekit-ffi

echo "Building provekit-ffi for $IOS_SIM..."
cargo build --release --target "$IOS_SIM" -p provekit-ffi

popd > /dev/null

# --- Build all zk-ffi backends ---
# Each backend in the zkffi workspace is built and merged into the
# xcframework. To add a new backend, just add its crate to the zkffi
# workspace — it will be picked up automatically.
pushd "$ZK_FFI_DIR" > /dev/null

echo ""
echo "Building zk-ffi backends for $IOS_DEVICE..."
cargo build --release --target "$IOS_DEVICE"

echo "Building zk-ffi backends for $IOS_SIM..."
cargo build --release --target "$IOS_SIM"

popd > /dev/null

# --- Collect all static libs ---
echo ""
echo "Merging static libraries..."

MERGED_DIR=$(mktemp -d)
mkdir -p "$MERGED_DIR/ios-arm64" "$MERGED_DIR/ios-arm64-sim"

# Find all .a files produced by zk-ffi backends
ZK_FFI_LIBS_DEVICE=$(find "$ZK_FFI_DIR/target/$IOS_DEVICE/release" -maxdepth 1 -name "lib*.a" -type f)
ZK_FFI_LIBS_SIM=$(find "$ZK_FFI_DIR/target/$IOS_SIM/release" -maxdepth 1 -name "lib*.a" -type f)

libtool -static -o "$MERGED_DIR/ios-arm64/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_DEVICE/release/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_DEVICE

libtool -static -o "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_SIM/release/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_SIM

echo "Merged libs (device): libprovekit_ffi.a $ZK_FFI_LIBS_DEVICE"
echo "Merged libs (sim):    libprovekit_ffi.a $ZK_FFI_LIBS_SIM"

# --- Create headers + modulemap ---
HEADERS_DIR=$(mktemp -d)
cp "$SDK_DIR/include/verity_ffi_raw.h" "$HEADERS_DIR/verity_ffi_raw.h"
cat > "$HEADERS_DIR/module.modulemap" <<'MODULEMAP'
module VerityFFI {
    header "verity_ffi_raw.h"
    link "verity"
    export *
}
MODULEMAP

# --- Create xcframework ---
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/Verity.xcframework"

echo ""
echo "Creating xcframework..."
xcodebuild -create-xcframework \
    -library "$MERGED_DIR/ios-arm64/libverity.a" \
    -headers "$HEADERS_DIR" \
    -library "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/Verity.xcframework"

# Clean up temp dirs
rm -rf "$HEADERS_DIR" "$MERGED_DIR"

echo ""
echo "=== Done! ==="
echo "xcframework: $OUTPUT_DIR/Verity.xcframework"
echo ""
echo "To release, run: bash scripts/release.sh <version>"
