#!/bin/bash
# Resolve ProveKit path, cloning into the repo root if not found.
#
# Source this script, then call: ensure_provekit [path]
# On success, PROVEKIT_ROOT is set to the absolute path.

PROVEKIT_REPO_URL="https://github.com/worldfnd/provekit.git"
PROVEKIT_DEFAULT_REF="v1"

ensure_provekit() {
    local candidate="${1:-${REPO_DIR:-.}/provekit}"

    if [ -d "$candidate" ]; then
        PROVEKIT_ROOT="$(cd "$candidate" && pwd)"
    else
        echo "ProveKit not found at $candidate — cloning..."
        git clone "$PROVEKIT_REPO_URL" "$candidate"
        git -C "$candidate" checkout "$PROVEKIT_DEFAULT_REF"
        PROVEKIT_ROOT="$(cd "$candidate" && pwd)"
        echo "ProveKit cloned to $PROVEKIT_ROOT (ref: $PROVEKIT_DEFAULT_REF)"
    fi

    if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
        echo "ERROR: Invalid ProveKit directory — Cargo.toml not found at $PROVEKIT_ROOT"
        return 1
    fi

    export PROVEKIT_ROOT
}
