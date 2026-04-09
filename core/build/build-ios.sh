#!/bin/bash
set -euo pipefail

#
# Usage:
#   bash core/build/build-ios.sh [provekit-path] [--backends provekit|bb|all]
#
# If provekit-path is omitted, defaults to ./provekit at the repo root.
# If ProveKit is not found, it is cloned automatically and checked out to v1.
#
# Examples:
#   bash core/build/build-ios.sh                         # Auto-detect / clone ProveKit
#   bash core/build/build-ios.sh provekit                # Explicit path (repo root)
#   bash core/build/build-ios.sh --backends all          # ProveKit + Barretenberg
#   bash core/build/build-ios.sh --backends bb           # Barretenberg only
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"

source "$REPO_DIR/scripts/ensure-provekit.sh"

IOS_DEVICE="aarch64-apple-ios"
IOS_SIM="aarch64-apple-ios-sim"
MACOS_ARM64="aarch64-apple-darwin"
MACOS_X86="x86_64-apple-darwin"

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
PROVEKIT_PROFILE="${PROVEKIT_PROFILE:-$CARGO_PROFILE}"
IOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
MACOS_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
export CMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
export CARGO_PROFILE_RELEASE_MOBILE_DEBUG=0

PROVEKIT_BRANCH=$(git -C "$PROVEKIT_ROOT" rev-parse --abbrev-ref HEAD)
VERITY_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)

echo "=== Building Verity core for iOS + macOS ==="
echo "ProveKit root:    $PROVEKIT_ROOT"
echo "ProveKit branch:  $PROVEKIT_BRANCH ($(git -C "$PROVEKIT_ROOT" rev-parse --short HEAD))"
echo "Verity branch:    $VERITY_BRANCH ($(git -C "$REPO_DIR" rev-parse --short HEAD))"
echo "Backends:         $BACKENDS (pk=$BUILD_PK, bb=$BUILD_BB)"
echo "Cargo profile:    $CARGO_PROFILE (core), $PROVEKIT_PROFILE (provekit)"
echo "iOS deployment:   $IOS_DEPLOYMENT_TARGET"
echo "macOS deployment: $MACOS_DEPLOYMENT_TARGET"
echo ""

rustup target add "$IOS_DEVICE" "$IOS_SIM" "$MACOS_ARM64" "$MACOS_X86" 2>/dev/null || true

# --- Build ProveKit ---
if $BUILD_PK; then
    pushd "$PROVEKIT_ROOT" > /dev/null
    echo "Building provekit-ffi for $IOS_DEVICE..."
    cargo build --profile "$PROVEKIT_PROFILE" --target "$IOS_DEVICE" -p provekit-ffi
    echo "Building provekit-ffi for $IOS_SIM..."
    cargo build --profile "$PROVEKIT_PROFILE" --target "$IOS_SIM" -p provekit-ffi
    echo "Building provekit-ffi for $MACOS_ARM64..."
    MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" cargo build --profile "$PROVEKIT_PROFILE" --target "$MACOS_ARM64" -p provekit-ffi
    echo "Building provekit-ffi for $MACOS_X86..."
    MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" cargo build --profile "$PROVEKIT_PROFILE" --target "$MACOS_X86" -p provekit-ffi
    popd > /dev/null
fi

# --- Build Barretenberg ---
if $BUILD_BB; then
    pushd "$CORE_DIR" > /dev/null
    echo "Building barretenberg-ffi for $IOS_DEVICE..."
    cargo build --profile "$CARGO_PROFILE" --target "$IOS_DEVICE" -p barretenberg-ffi
    echo "Building barretenberg-ffi for $IOS_SIM..."
    cargo build --profile "$CARGO_PROFILE" --target "$IOS_SIM" -p barretenberg-ffi
    echo "Building barretenberg-ffi for $MACOS_ARM64..."
    MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" cargo build --profile "$CARGO_PROFILE" --target "$MACOS_ARM64" -p barretenberg-ffi
    echo "Building barretenberg-ffi for $MACOS_X86..."
    MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" cargo build --profile "$CARGO_PROFILE" --target "$MACOS_X86" -p barretenberg-ffi
    popd > /dev/null
fi

# --- Merge static libraries ---
echo "Preparing static libraries..."
MERGED_DIR=$(mktemp -d)
mkdir -p "$MERGED_DIR/ios-arm64" "$MERGED_DIR/ios-arm64-sim" "$MERGED_DIR/macos-arm64" "$MERGED_DIR/macos-x86_64"

for arch_pair in "$IOS_DEVICE:ios-arm64" "$IOS_SIM:ios-arm64-sim" "$MACOS_ARM64:macos-arm64" "$MACOS_X86:macos-x86_64"; do
    RUST_TARGET="${arch_pair%%:*}"
    ARCH_DIR="${arch_pair##*:}"
    LIBS_TO_MERGE=()

    # macOS targets use the ProveKit profile dir same as iOS
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

# Create universal macOS binary
echo "Creating universal macOS binary..."
mkdir -p "$MERGED_DIR/macos-universal"
lipo -create \
    "$MERGED_DIR/macos-arm64/libverity.a" \
    "$MERGED_DIR/macos-x86_64/libverity.a" \
    -output "$MERGED_DIR/macos-universal/libverity.a"

# Strip debug symbols
echo "Stripping debug symbols..."
strip -S -x "$MERGED_DIR/ios-arm64/libverity.a"
strip -S -x "$MERGED_DIR/ios-arm64-sim/libverity.a"
strip -S -x "$MERGED_DIR/macos-universal/libverity.a"

echo "Library sizes:"
ls -lh "$MERGED_DIR/ios-arm64/libverity.a"
ls -lh "$MERGED_DIR/ios-arm64-sim/libverity.a"
ls -lh "$MERGED_DIR/macos-universal/libverity.a"

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
    -library "$MERGED_DIR/macos-universal/libverity.a" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/Verity.xcframework"

# Write a marker so Package.swift knows which backends are available
echo "$BACKENDS" > "$OUTPUT_DIR/Verity.xcframework/backends"

rm -rf "$HEADERS_DIR" "$MERGED_DIR"

echo "=== Done: $OUTPUT_DIR/Verity.xcframework (backends: $BACKENDS, platforms: iOS + macOS) ==="
