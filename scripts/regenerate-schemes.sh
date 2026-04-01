#!/bin/bash
set -euo pipefail

#
# Regenerate pre-compiled .pkp/.pkv scheme files for the iOS demo app
# using provekit-cli directly.
#
# Usage:
#   bash scripts/regenerate-schemes.sh [provekit-path]
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROVEKIT_ROOT="${1:-$(cd "$REPO_DIR/../provekit" && pwd)}"
CIRCUITS_DIR="$REPO_DIR/examples/ios/VerityDemo/VerityDemo/Resources/circuits"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    echo "Usage: bash scripts/regenerate-schemes.sh [provekit-path]"
    exit 1
fi

echo "=== Regenerating .pkp/.pkv scheme files ==="
echo "ProveKit: $PROVEKIT_ROOT ($(git -C "$PROVEKIT_ROOT" rev-parse --short HEAD))"
echo ""

for circuit_dir in "$CIRCUITS_DIR"/*/; do
    prefix=$(basename "$circuit_dir")
    json="$circuit_dir/${prefix}_circuit.json"
    pkp="$circuit_dir/${prefix}_prover.pkp"
    pkv="$circuit_dir/${prefix}_verifier.pkv"

    if [ ! -f "$json" ]; then
        echo "WARNING: No circuit JSON at $json, skipping"
        continue
    fi

    echo "[$prefix]"
    # Run from provekit dir so rust-toolchain.toml (nightly) is picked up
    (cd "$PROVEKIT_ROOT" && cargo run --release --bin provekit-cli -- \
        prepare "$json" --pkp "$pkp" --pkv "$pkv")
    echo "  pkp: $(du -h "$pkp" | cut -f1), pkv: $(du -h "$pkv" | cut -f1)"
    echo ""
done

echo "Done. Rebuild the iOS app to bundle the updated schemes."
