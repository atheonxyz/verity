#!/bin/bash
set -euo pipefail

#
# Usage:
#   bash core/build/build-ios.sh <provekit-path> [--backends provekit|bb|all]
#
# Examples:
#   bash core/build/build-ios.sh ../provekit                     # ProveKit only (default)
#   bash core/build/build-ios.sh ../provekit --backends all       # ProveKit + Barretenberg
#   bash core/build/build-ios.sh ../provekit --backends bb        # Barretenberg only
#   bash core/build/build-ios.sh ../provekit --backends provekit  # ProveKit only
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"

IOS_DEVICE="aarch64-apple-ios"
IOS_SIM="aarch64-apple-ios-sim"

# Parse arguments
PROVEKIT_ROOT=""
BACKENDS="provekit"

while [ $# -gt 0 ]; do
    case "$1" in
        --backends)
            BACKENDS="$2"
            shift 2
            ;;
        *)
            if [ -z "$PROVEKIT_ROOT" ]; then
                PROVEKIT_ROOT="$(cd "$1" && pwd)"
            else
                echo "ERROR: Unknown argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$PROVEKIT_ROOT" ]; then
    echo "Usage: bash core/build/build-ios.sh <provekit-path> [--backends provekit|bb|all]"
    exit 1
fi

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

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
PROVEKIT_PROFILE="${PROVEKIT_PROFILE:-$CARGO_PROFILE}"
IOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
export CMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
export CARGO_PROFILE_RELEASE_MOBILE_DEBUG=0

PROVEKIT_BRANCH=$(git -C "$PROVEKIT_ROOT" rev-parse --abbrev-ref HEAD)
VERITY_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)

echo "=== Building Verity core for iOS ==="
echo "ProveKit root:    $PROVEKIT_ROOT"
echo "ProveKit branch:  $PROVEKIT_BRANCH ($(git -C "$PROVEKIT_ROOT" rev-parse --short HEAD))"
echo "Verity branch:    $VERITY_BRANCH ($(git -C "$REPO_DIR" rev-parse --short HEAD))"
echo "Backends:         $BACKENDS (pk=$BUILD_PK, bb=$BUILD_BB)"
echo "Cargo profile:    $CARGO_PROFILE (core), $PROVEKIT_PROFILE (provekit)"
echo "iOS deployment:   $IOS_DEPLOYMENT_TARGET"
echo ""

rustup target add "$IOS_DEVICE" "$IOS_SIM" 2>/dev/null || true

# --- Build ProveKit ---
if $BUILD_PK; then
    pushd "$PROVEKIT_ROOT" > /dev/null
    echo "Building provekit-ffi for $IOS_DEVICE..."
    cargo build --profile "$PROVEKIT_PROFILE" --target "$IOS_DEVICE" -p provekit-ffi
    echo "Building provekit-ffi for $IOS_SIM..."
    cargo build --profile "$PROVEKIT_PROFILE" --target "$IOS_SIM" -p provekit-ffi
    popd > /dev/null
fi

# --- Build Barretenberg ---
if $BUILD_BB; then
    pushd "$CORE_DIR" > /dev/null
    echo "Building barretenberg-ffi for $IOS_DEVICE..."
    cargo build --profile "$CARGO_PROFILE" --target "$IOS_DEVICE" -p barretenberg-ffi
    echo "Building barretenberg-ffi for $IOS_SIM..."
    cargo build --profile "$CARGO_PROFILE" --target "$IOS_SIM" -p barretenberg-ffi
    popd > /dev/null
fi

# --- Merge static libraries ---
echo "Preparing static libraries..."
MERGED_DIR=$(mktemp -d)
mkdir -p "$MERGED_DIR/ios-arm64" "$MERGED_DIR/ios-arm64-sim"

for arch_pair in "$IOS_DEVICE:ios-arm64" "$IOS_SIM:ios-arm64-sim"; do
    RUST_TARGET="${arch_pair%%:*}"
    ARCH_DIR="${arch_pair##*:}"
    LIBS_TO_MERGE=()

    if $BUILD_PK; then
        LIBS_TO_MERGE+=("$PROVEKIT_ROOT/target/$RUST_TARGET/$PROVEKIT_PROFILE/libprovekit_ffi.a")
    fi
    if $BUILD_BB; then
        LIBS_TO_MERGE+=("$CORE_DIR/target/$RUST_TARGET/$CARGO_PROFILE/libbarretenberg_ffi.a")
    fi

    if [ ${#LIBS_TO_MERGE[@]} -eq 1 ]; then
        cp "${LIBS_TO_MERGE[0]}" "$MERGED_DIR/$ARCH_DIR/libverity.a"
    else
        # Merge multiple static libs into one
        libtool -static -o "$MERGED_DIR/$ARCH_DIR/libverity.a" "${LIBS_TO_MERGE[@]}"
    fi
done

# Strip debug symbols
echo "Stripping debug symbols..."
strip -S -x "$MERGED_DIR/ios-arm64/libverity.a"
strip -S -x "$MERGED_DIR/ios-arm64-sim/libverity.a"

echo "Library sizes:"
ls -lh "$MERGED_DIR/ios-arm64/libverity.a"
ls -lh "$MERGED_DIR/ios-arm64-sim/libverity.a"

# --- Create XCFramework ---
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

# Write a marker so Package.swift knows which backends are available
echo "$BACKENDS" > "$OUTPUT_DIR/Verity.xcframework/backends"

rm -rf "$HEADERS_DIR" "$MERGED_DIR"

echo "=== Done: $OUTPUT_DIR/Verity.xcframework (backends: $BACKENDS) ==="
