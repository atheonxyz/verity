#!/bin/bash
set -euo pipefail

# Build core libraries for Android.
#
# Produces dynamic libraries (.so) for provekit-ffi and static libraries
# for core backends. Android loads .so files at runtime via System.loadLibrary().
#
# Usage:
#   bash core/build/build-android.sh <provekit-path>
#   bash core/build/build-android.sh ../provekit
#
# ProveKit branch: ash/v1-ffi-sdk

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

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

CARGO_PROFILE="${CARGO_PROFILE:-release-mobile}"
PROVEKIT_PROFILE="${PROVEKIT_PROFILE:-$CARGO_PROFILE}"
echo "Using cargo profile: $CARGO_PROFILE (core), $PROVEKIT_PROFILE (provekit)"

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

# Build provekit-ffi as cdylib (.so) for Android
pushd "$PROVEKIT_ROOT" > /dev/null
for TARGET in "${TARGETS[@]}"; do
    echo "Building provekit-ffi (cdylib) for $TARGET..."
    cargo rustc --profile "$PROVEKIT_PROFILE" --target "$TARGET" -p provekit-ffi --crate-type cdylib
done
popd > /dev/null

# Build all core backends
pushd "$CORE_DIR" > /dev/null
for TARGET in "${TARGETS[@]}"; do
    echo "Building core backends for $TARGET..."
    cargo build --profile "$CARGO_PROFILE" --target "$TARGET"
done
popd > /dev/null

for ABI in "${OUTPUT_ABIS[@]}"; do
    mkdir -p "$OUTPUT_DIR/$ABI"
done

for INDEX in "${!TARGETS[@]}"; do
    TARGET="${TARGETS[$INDEX]}"
    ABI="${OUTPUT_ABIS[$INDEX]}"

    find "$PROVEKIT_ROOT/target/$TARGET/$PROVEKIT_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;
    find "$CORE_DIR/target/$TARGET/$CARGO_PROFILE" -maxdepth 1 \( -name "*.so" -o -name "lib*.a" \) -exec cp {} "$OUTPUT_DIR/$ABI/" \;
done

echo ""
echo "Output sizes:"
for ABI in "${OUTPUT_ABIS[@]}"; do
    ls -lh "$OUTPUT_DIR/$ABI/"*.so 2>/dev/null || echo "  (no .so files for $ABI)"
done

echo "=== Done: $OUTPUT_DIR ==="
