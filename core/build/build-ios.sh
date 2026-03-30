#!/bin/bash
set -euo pipefail

# Build core libraries for iOS (device + simulator).
#
# Usage:
#   bash core/build/build-ios.sh <provekit-path>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"

IOS_DEVICE="aarch64-apple-ios"
IOS_SIM="aarch64-apple-ios-sim"

if [ $# -lt 1 ]; then
    echo "Usage: bash core/build/build-ios.sh <provekit-path>"
    exit 1
fi

PROVEKIT_ROOT="$(cd "$1" && pwd)"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

echo "=== Building Verity core for iOS ==="

rustup target add "$IOS_DEVICE" "$IOS_SIM" 2>/dev/null || true

CARGO_PROFILE="${CARGO_PROFILE:-release-mobile}"
echo "Using cargo profile: $CARGO_PROFILE"

pushd "$PROVEKIT_ROOT" > /dev/null
echo "Building provekit-ffi for $IOS_DEVICE..."
cargo build --profile "$CARGO_PROFILE" --target "$IOS_DEVICE" -p provekit-ffi
echo "Building provekit-ffi for $IOS_SIM..."
cargo build --profile "$CARGO_PROFILE" --target "$IOS_SIM" -p provekit-ffi
popd > /dev/null

pushd "$CORE_DIR" > /dev/null
echo "Building core backends for $IOS_DEVICE..."
cargo build --profile "$CARGO_PROFILE" --target "$IOS_DEVICE"
echo "Building core backends for $IOS_SIM..."
cargo build --profile "$CARGO_PROFILE" --target "$IOS_SIM"
popd > /dev/null

echo "Merging static libraries..."
MERGED_DIR=$(mktemp -d)
mkdir -p "$MERGED_DIR/ios-arm64" "$MERGED_DIR/ios-arm64-sim"

ZK_FFI_LIBS_DEVICE=$(find "$CORE_DIR/target/$IOS_DEVICE/$CARGO_PROFILE" -maxdepth 1 -name "lib*.a" -type f)
ZK_FFI_LIBS_SIM=$(find "$CORE_DIR/target/$IOS_SIM/$CARGO_PROFILE" -maxdepth 1 -name "lib*.a" -type f)

libtool -static -o "$MERGED_DIR/ios-arm64/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_DEVICE/$CARGO_PROFILE/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_DEVICE

libtool -static -o "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_SIM/$CARGO_PROFILE/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_SIM

# Strip debug symbols to reduce library size
echo "Stripping debug symbols..."
strip -S -x "$MERGED_DIR/ios-arm64/libverity.a"
strip -S -x "$MERGED_DIR/ios-arm64-sim/libverity.a"

echo "Library sizes:"
ls -lh "$MERGED_DIR/ios-arm64/libverity.a"
ls -lh "$MERGED_DIR/ios-arm64-sim/libverity.a"

HEADERS_DIR=$(mktemp -d)
cp "$CORE_DIR/include/verity_ffi_raw.h" "$HEADERS_DIR/verity_ffi_raw.h"
cat > "$HEADERS_DIR/module.modulemap" <<'MODULEMAP'
module VerityFFI {
    header "verity_ffi_raw.h"
    link "verity"
    export *
}
MODULEMAP

mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/Verity.xcframework"

echo "Creating xcframework..."
xcodebuild -create-xcframework \
    -library "$MERGED_DIR/ios-arm64/libverity.a" \
    -headers "$HEADERS_DIR" \
    -library "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/Verity.xcframework"

rm -rf "$HEADERS_DIR" "$MERGED_DIR"

echo "=== Done: $OUTPUT_DIR/Verity.xcframework ==="
