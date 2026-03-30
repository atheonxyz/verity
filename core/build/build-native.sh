#!/bin/bash
set -euo pipefail

# Build core libraries for the host platform (testing + Node N-API).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Building Verity core for host ==="

pushd "$CORE_DIR" > /dev/null
cargo build --release
popd > /dev/null

echo "=== Done ==="
