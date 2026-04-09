#!/bin/bash
set -euo pipefail

#
# Regenerate pre-compiled .pkp/.pkv scheme files for iOS and Android demo apps
# using provekit-cli directly.
#
# Usage:
#   bash scripts/regenerate-schemes.sh [provekit-path]
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_DIR/scripts/ensure-provekit.sh"
ensure_provekit "${1:-$REPO_DIR/provekit}"

IOS_CIRCUITS="$REPO_DIR/examples/ios/VerityDemo/VerityDemo/Resources/circuits"
ANDROID_CIRCUITS="$REPO_DIR/examples/android/VerityDemo/app/src/main/assets/circuits"

echo "=== Regenerating .pkp/.pkv scheme files ==="
echo "ProveKit: $PROVEKIT_ROOT ($(git -C "$PROVEKIT_ROOT" rev-parse --short HEAD))"
echo ""

# Collect all circuit JSONs to prepare (deduplicated by content)
# iOS uses: {prefix}_circuit.json → {prefix}_prover.pkp / {prefix}_verifier.pkv
# Android uses: circuit.json → prover.pkp / verifier.pkv

prepare_circuit() {
    local json="$1"
    local pkp="$2"
    local pkv="$3"
    local label="$4"

    echo "  [$label]"
    (cd "$PROVEKIT_ROOT" && cargo run --profile release-mobile --bin provekit-cli -- \
        prepare "$json" --pkp "$pkp" --pkv "$pkv" 2>&1 | grep -E "INFO|Wrote|error" || true)
    echo "    pkp: $(du -h "$pkp" | cut -f1), pkv: $(du -h "$pkv" | cut -f1)"
}

# --- iOS circuits ---
if [ -d "$IOS_CIRCUITS" ]; then
    echo "iOS circuits:"
    for circuit_dir in "$IOS_CIRCUITS"/*/; do
        prefix=$(basename "$circuit_dir")
        json="$circuit_dir/${prefix}_circuit.json"

        if [ -f "$json" ]; then
            # Non-fragmented: {prefix}_circuit.json at top level
            prepare_circuit "$json" \
                "$circuit_dir/${prefix}_prover.pkp" \
                "$circuit_dir/${prefix}_verifier.pkv" \
                "ios/$prefix"
        else
            # Fragmented: each step subdirectory has {step}_circuit.json
            for step_dir in "$circuit_dir"/*/; do
                [ -d "$step_dir" ] || continue
                step=$(basename "$step_dir")
                step_json="$step_dir/${step}_circuit.json"
                [ -f "$step_json" ] || continue
                prepare_circuit "$step_json" \
                    "$step_dir/${step}_prover.pkp" \
                    "$step_dir/${step}_verifier.pkv" \
                    "ios/$prefix/$step"
            done
        fi
    done
    echo ""
fi

# --- Android circuits (non-fragmented) ---
if [ -d "$ANDROID_CIRCUITS" ]; then
    echo "Android circuits:"
    for circuit_dir in "$ANDROID_CIRCUITS"/*/; do
        prefix=$(basename "$circuit_dir")
        json="$circuit_dir/circuit.json"

        # Skip fragmented circuits (they have subdirectories, not a direct circuit.json)
        [ -f "$json" ] || continue

        prepare_circuit "$json" \
            "$circuit_dir/prover.pkp" \
            "$circuit_dir/verifier.pkv" \
            "android/$prefix"
    done

    # Fragmented circuits — each step has its own circuit.json
    for frag_dir in "$ANDROID_CIRCUITS"/fragmented_*/; do
        [ -d "$frag_dir" ] || continue
        frag_name=$(basename "$frag_dir")
        for step_dir in "$frag_dir"/*/; do
            step=$(basename "$step_dir")
            json="$step_dir/circuit.json"
            [ -f "$json" ] || continue
            prepare_circuit "$json" \
                "$step_dir/prover.pkp" \
                "$step_dir/verifier.pkv" \
                "android/$frag_name/$step"
        done
    done
    echo ""
fi

echo "Done. Rebuild iOS/Android apps to bundle the updated schemes."
