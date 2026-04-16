#!/bin/bash
set -euo pipefail

# Build core libraries for WASM (browser target).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/wasm"
JS_WASM_DIR="$REPO_DIR/sdks/js/wasm"
TARGET_DIR="$REPO_DIR/.build/provekit-wasm-target"

source "$REPO_DIR/scripts/ensure-provekit.sh"

resolve_provekit_path() {
    if [ -n "${1:-}" ]; then
        printf '%s\n' "$1"
        return
    fi
    if [ -n "${PROVEKIT_PATH:-}" ]; then
        printf '%s\n' "$PROVEKIT_PATH"
        return
    fi
    if [ -d "$REPO_DIR/../provekit" ]; then
        printf '%s\n' "$REPO_DIR/../provekit"
        return
    fi
    printf '%s\n' "$REPO_DIR/provekit"
}

patch_worker_helpers() {
    local snippets_dir="$1/snippets"

    if [ ! -d "$snippets_dir" ]; then
        return
    fi

    while IFS= read -r -d '' helper; do
        perl -0pi -e "s#import\\('\\.\\./\\.\\./\\.\\.'\\)#import('../../../provekit_wasm.js')#g" "$helper"
    done < <(find "$snippets_dir" -name 'workerHelpers.js' -print0)
}

echo "=== Building Verity core for WASM ==="

ensure_provekit "$(resolve_provekit_path "${1:-}")"

echo "ProveKit root: $PROVEKIT_ROOT"

mkdir -p "$OUTPUT_DIR" "$JS_WASM_DIR"
find "$JS_WASM_DIR" -mindepth 1 ! -name '.gitignore' -exec rm -rf {} +

WASM_MANIFEST="$PROVEKIT_ROOT/tooling/provekit-wasm/Cargo.toml"

if [ ! -f "$WASM_MANIFEST" ]; then
    echo "ERROR: ProveKit WASM crate not found at $WASM_MANIFEST"
    exit 1
fi

echo "Building ProveKit WASM package..."
pushd "$PROVEKIT_ROOT" > /dev/null
cargo build \
    --release \
    --target wasm32-unknown-unknown \
    -p provekit-wasm \
    --target-dir "$TARGET_DIR" \
    -Z build-std=panic_abort,std
popd > /dev/null

wasm-bindgen \
    --target web \
    --out-dir "$JS_WASM_DIR" \
    "$TARGET_DIR/wasm32-unknown-unknown/release/provekit_wasm.wasm"

patch_worker_helpers "$JS_WASM_DIR"

if command -v wasm-opt >/dev/null 2>&1; then
    wasm-opt \
        -O3 \
        --enable-simd \
        --enable-threads \
        --enable-bulk-memory \
        --enable-mutable-globals \
        --enable-nontrapping-float-to-int \
        --enable-sign-ext \
        --fast-math \
        -o "$JS_WASM_DIR/provekit_wasm_bg.wasm" \
        "$JS_WASM_DIR/provekit_wasm_bg.wasm"
fi

for backend_dir in "$CORE_DIR"/backends/*/; do
    if [ -f "$backend_dir/backend.toml" ]; then
        wasm_type=$(grep -A1 '\[targets.wasm\]' "$backend_dir/backend.toml" | grep 'type' | cut -d'"' -f2 || true)
        if [ "$wasm_type" = "rust-wasm" ]; then
            echo "Building $(basename "$backend_dir") for WASM..."
            pushd "$backend_dir" > /dev/null
            wasm-pack build --target web --out-dir "$OUTPUT_DIR/$(basename "$backend_dir")"
            popd > /dev/null
        elif [ "$wasm_type" = "vendor" ]; then
            echo "Skipping $(basename "$backend_dir") — uses vendor WASM"
        else
            echo "Skipping $(basename "$backend_dir") — no WASM target"
        fi
    fi
done

echo "=== Done: $OUTPUT_DIR + $JS_WASM_DIR ==="
