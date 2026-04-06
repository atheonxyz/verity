#!/usr/bin/env bash
# Generate .pkp/.pkv test fixtures from circuit.json files.
#
# Requires: core-native build (produces gen_fixtures binary).
# Usage:    bash tests/gen-fixtures.sh
#
# This script finds circuit.json fixtures in the test directories
# and generates corresponding prover.pkp / verifier.pkv files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEN_FIXTURES="$REPO_ROOT/core/target/gen_fixtures"

# Build gen_fixtures if not present
if [ ! -f "$GEN_FIXTURES" ]; then
    echo "Building gen_fixtures..."
    mkdir -p "$REPO_ROOT/core/target"
    # Link against the native-built static libraries
    echo "Compiling: cc -o $GEN_FIXTURES $SCRIPT_DIR/gen_fixtures.c ..."
    cc -o "$GEN_FIXTURES" \
        "$SCRIPT_DIR/gen_fixtures.c" \
        -L"$REPO_ROOT/core/target/release" \
        -lverity_provekit -lverity_barretenberg \
        -lpthread -ldl -lm -lc++ \
        || {
            echo "Error: Failed to build gen_fixtures."
            echo "  - Ensure core-native has been built (make core-native)"
            echo "  - Check that static libs exist in core/target/release/"
            exit 1
        }
fi

# Generate fixtures for Swift tests
SWIFT_FIXTURES="$REPO_ROOT/sdks/swift/Tests/VerityTests/Fixtures"
if [ -f "$SWIFT_FIXTURES/circuit.json" ]; then
    echo "Generating Swift test fixtures..."
    "$GEN_FIXTURES" pk "$SWIFT_FIXTURES/circuit.json" "$SWIFT_FIXTURES"
fi

# Generate fixtures for Kotlin tests
KOTLIN_FIXTURES="$REPO_ROOT/sdks/kotlin/src/androidTest/assets/fixtures"
if [ -f "$KOTLIN_FIXTURES/circuit.json" ]; then
    echo "Generating Kotlin test fixtures..."
    "$GEN_FIXTURES" pk "$KOTLIN_FIXTURES/circuit.json" "$KOTLIN_FIXTURES"
fi

echo "Fixture generation complete."
