#!/bin/bash
set -euo pipefail

# Build core libraries for WASM (browser target).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/wasm"

echo "=== Building Verity core for WASM ==="

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

echo "=== Done: $OUTPUT_DIR ==="
