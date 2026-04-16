#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_PROVEKIT="$REPO_ROOT/../provekit"
TARGET_DIR="$REPO_ROOT/.build/provekit-cli-target"
CLI_BIN="$TARGET_DIR/release-fast/provekit-cli"
SDK_FIXTURES_DIR="$REPO_ROOT/sdks/js/tests/fixtures"
DEMO_ARTIFACTS_DIR="$REPO_ROOT/examples/js/browser-example/artifacts"

source "$REPO_ROOT/scripts/ensure-provekit.sh"

ensure_provekit "${1:-${PROVEKIT_PATH:-$DEFAULT_PROVEKIT}}"

mkdir -p "$SDK_FIXTURES_DIR" "$DEMO_ARTIFACTS_DIR"

echo "=== Building ProveKit CLI ==="
pushd "$PROVEKIT_ROOT" > /dev/null
cargo build \
    --profile release-fast \
    --bin provekit-cli \
    --target-dir "$TARGET_DIR"
popd > /dev/null

echo "=== Generating JS fixtures with ProveKit ==="
"$CLI_BIN" prepare \
    "$REPO_ROOT/circuits/fixtures/circuit.json" \
    --pkp "$SDK_FIXTURES_DIR/prover.pkp" \
    --pkv "$SDK_FIXTURES_DIR/verifier.pkv"

cp "$SDK_FIXTURES_DIR/prover.pkp" "$DEMO_ARTIFACTS_DIR/prover.pkp"
cp "$SDK_FIXTURES_DIR/verifier.pkv" "$DEMO_ARTIFACTS_DIR/verifier.pkv"
cp "$REPO_ROOT/circuits/fixtures/inputs.json" "$SDK_FIXTURES_DIR/inputs.json"
cp "$REPO_ROOT/circuits/fixtures/inputs.json" "$DEMO_ARTIFACTS_DIR/inputs.json"

echo "=== Done ==="
echo "SDK fixtures:  $SDK_FIXTURES_DIR"
echo "Demo assets:   $DEMO_ARTIFACTS_DIR"
