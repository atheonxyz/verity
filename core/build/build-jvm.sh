#!/bin/bash
set -euo pipefail

# Build libverity_jni.{dylib,so} for desktop JVM targets.
#
# Targets:
#   macOS:  darwin-aarch64, darwin-x86_64
#   Linux:  linux-x86_64
#
# Prerequisites:
#   1. Rust static libs must already be built for the needed targets.
#      Run `cargo build --release --target <triple>` from core/backends/,
#      or run core/build/build-native.sh for the host target.
#   2. JAVA_HOME must be set (or auto-detected from `java` on PATH).
#
# Usage:
#   bash core/build/build-jvm.sh [provekit-path]
#   PROVEKIT_ROOT=provekit bash core/build/build-jvm.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"

source "$REPO_DIR/scripts/ensure-provekit.sh"
ensure_provekit "${1:-${PROVEKIT_ROOT:-$REPO_DIR/provekit}}"
DISPATCHER_DIR="$CORE_DIR/dispatcher"
INCLUDE_DIR="$CORE_DIR/include"
JNI_SRC="$REPO_DIR/sdks/kotlin/src/main/jni/verity_jni.c"
OUTPUT_BASE="$REPO_DIR/output/jvm"
CARGO_PROFILE="${CARGO_PROFILE:-release}"

# ---------------------------------------------------------------------------
# Resolve JAVA_HOME
# ---------------------------------------------------------------------------
if [ -z "${JAVA_HOME:-}" ]; then
    if command -v java >/dev/null 2>&1; then
        JAVA_EXEC="$(command -v java)"
        # Resolve symlinks
        while [ -L "$JAVA_EXEC" ]; do
            JAVA_EXEC="$(readlink "$JAVA_EXEC")"
        done
        JAVA_HOME="$(cd "$(dirname "$JAVA_EXEC")/.." && pwd)"
    fi
fi

if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "ERROR: Cannot find JAVA_HOME. Set JAVA_HOME or ensure 'java' is on PATH."
    exit 1
fi

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
if [ ! -f "$JNI_SRC" ]; then
    echo "ERROR: JNI bridge not found at $JNI_SRC"
    exit 1
fi

if [ ! -f "$DISPATCHER_DIR/verity_dispatch.c" ]; then
    echo "ERROR: Dispatcher not found at $DISPATCHER_DIR/verity_dispatch.c"
    exit 1
fi

HOST_OS="$(uname -s)"

echo "=== Building libverity_jni for desktop JVM ==="
echo "Core dir:      $CORE_DIR"
echo "Repo dir:      $REPO_DIR"
echo "JAVA_HOME:     $JAVA_HOME"
echo "Cargo profile: $CARGO_PROFILE"
if [ -n "$PROVEKIT_ROOT" ]; then
    echo "ProveKit root: $PROVEKIT_ROOT"
fi
echo ""

# ---------------------------------------------------------------------------
# Define targets depending on host OS
# ---------------------------------------------------------------------------
if [ "$HOST_OS" = "Darwin" ]; then
    TARGETS=(
        "aarch64-apple-darwin:darwin-aarch64:aarch64-apple-macos:dylib"
        "x86_64-apple-darwin:darwin-x86_64:x86_64-apple-macos:dylib"
    )
elif [ "$HOST_OS" = "Linux" ]; then
    TARGETS=(
        "x86_64-unknown-linux-gnu:linux-x86_64::so"
    )
else
    echo "ERROR: Unsupported host OS: $HOST_OS (only macOS and Linux are supported)"
    exit 1
fi

# ---------------------------------------------------------------------------
# Build loop
# ---------------------------------------------------------------------------
for entry in "${TARGETS[@]}"; do
    RUST_TARGET="${entry%%:*}"
    rest="${entry#*:}"
    JVM_TARGET="${rest%%:*}"
    rest="${rest#*:}"
    CLANG_TARGET="${rest%%:*}"
    EXT="${rest##*:}"

    LIB_NAME="libverity_jni.$EXT"
    OUTPUT_DIR="$OUTPUT_BASE/$JVM_TARGET"
    OUTPUT_LIB="$OUTPUT_DIR/$LIB_NAME"

    echo "--- Building for $RUST_TARGET ($JVM_TARGET) ---"

    # Resolve JNI include directories
    if [ "$HOST_OS" = "Darwin" ]; then
        JNI_INCLUDE_PLATFORM="$JAVA_HOME/include/darwin"
    else
        JNI_INCLUDE_PLATFORM="$JAVA_HOME/include/linux"
    fi
    JNI_INCLUDE="$JAVA_HOME/include"

    if [ ! -d "$JNI_INCLUDE" ]; then
        echo "  ERROR: JNI headers not found at $JNI_INCLUDE"
        echo "  Ensure JAVA_HOME points to a JDK (not JRE)."
        exit 1
    fi

    # Locate Rust static libs from output/jvm/<target>/ (primary) or core target dir (fallback)
    JVM_PREBUILT_DIR="$OUTPUT_BASE/$JVM_TARGET"
    CORE_TARGET_DIR="$CORE_DIR/target/$RUST_TARGET/$CARGO_PROFILE"
    PK_TARGET_DIR="${PROVEKIT_ROOT:+$PROVEKIT_ROOT/target/$RUST_TARGET/$CARGO_PROFILE}"

    # Detect which backends are available
    HAS_PK=false
    HAS_BB=false
    PK_LIB=""
    BB_LIB=""

    # Check output/jvm/<target>/ first, then core target dir
    for search_dir in "$JVM_PREBUILT_DIR" "$CORE_TARGET_DIR" "${PK_TARGET_DIR:-}"; do
        [ -n "$search_dir" ] || continue
        [ -d "$search_dir" ] || continue
        if [ -f "$search_dir/libprovekit_ffi.a" ] && ! $HAS_PK; then
            HAS_PK=true
            PK_LIB="$search_dir/libprovekit_ffi.a"
        fi
        if [ -f "$search_dir/libbarretenberg_ffi.a" ] && ! $HAS_BB; then
            HAS_BB=true
            BB_LIB="$search_dir/libbarretenberg_ffi.a"
        fi
    done

    echo "  Backends detected: pk=$HAS_PK (${PK_LIB:-none}), bb=$HAS_BB (${BB_LIB:-none})"

    if ! $HAS_PK && ! $HAS_BB; then
        echo "  WARNING: No static libraries found for $RUST_TARGET."
        echo "  Run 'cargo build --release --target $RUST_TARGET' in core/backends/ first."
        continue
    fi

    WORK_DIR=$(mktemp -d)
    trap 'rm -rf "$WORK_DIR"' EXIT

    # Build compiler invocation
    if [ "$HOST_OS" = "Darwin" ]; then
        CC="cc"
        CLANG_TARGET_FLAG=""
        if [ -n "$CLANG_TARGET" ]; then
            CLANG_TARGET_FLAG="-target $CLANG_TARGET"
        fi
    else
        CC="cc"
        CLANG_TARGET_FLAG=""
    fi

    COMMON_CFLAGS="-fPIC -O2 $CLANG_TARGET_FLAG"

    # Compile dispatch layer
    echo "  Compiling dispatch layer..."
    $CC $COMMON_CFLAGS \
        -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" \
        -c "$DISPATCHER_DIR/verity_dispatch.c" \
        -o "$WORK_DIR/verity_dispatch.o"

    BACKEND_OBJS=""
    if $HAS_PK; then
        $CC $COMMON_CFLAGS \
            -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" \
            -c "$DISPATCHER_DIR/backends/pk_backend.c" \
            -o "$WORK_DIR/pk_backend.o"
        BACKEND_OBJS="$BACKEND_OBJS $WORK_DIR/pk_backend.o"
    fi
    if $HAS_BB; then
        $CC $COMMON_CFLAGS \
            -I"$INCLUDE_DIR" -I"$DISPATCHER_DIR" \
            -c "$DISPATCHER_DIR/backends/bb_backend.c" \
            -o "$WORK_DIR/bb_backend.o"
        BACKEND_OBJS="$BACKEND_OBJS $WORK_DIR/bb_backend.o"
    fi

    # Compile JNI bridge
    echo "  Compiling JNI bridge..."
    $CC $COMMON_CFLAGS \
        -I"$INCLUDE_DIR" \
        -I"$JNI_INCLUDE" \
        -I"$JNI_INCLUDE_PLATFORM" \
        -c "$JNI_SRC" \
        -o "$WORK_DIR/verity_jni.o"

    # Collect static libraries with force-load/whole-archive for constructor symbols
    mkdir -p "$OUTPUT_DIR"

    if [ "$HOST_OS" = "Darwin" ]; then
        # macOS: -dynamiclib, -Wl,-force_load for each FFI static lib
        RUST_STATIC_FLAGS=""
        if $HAS_PK; then
            RUST_STATIC_FLAGS="$RUST_STATIC_FLAGS -Wl,-force_load,$PK_LIB"
        fi
        if $HAS_BB; then
            RUST_STATIC_FLAGS="$RUST_STATIC_FLAGS -Wl,-force_load,$BB_LIB"
        fi

        # Dependent static libs from provekit build directory (lzma, zstd, blake3, ring)
        DEP_LIBS=""
        if [ -n "${PK_TARGET_DIR:-}" ] && [ -d "$PK_TARGET_DIR/build" ]; then
            while IFS= read -r -d '' lib; do
                DEP_LIBS="$DEP_LIBS $lib"
            done < <(find "$PK_TARGET_DIR/build" -name "lib*.a" -print0 2>/dev/null)
        fi

        echo "  Linking $LIB_NAME (macOS)..."
        $CC $CLANG_TARGET_FLAG \
            -dynamiclib \
            -o "$OUTPUT_LIB" \
            -Wl,-allow_duplicates \
            "$WORK_DIR/verity_dispatch.o" \
            $BACKEND_OBJS \
            "$WORK_DIR/verity_jni.o" \
            $RUST_STATIC_FLAGS \
            $DEP_LIBS \
            -framework Security \
            -framework CoreFoundation \
            -lSystem \
            -lc++

        # Strip debug symbols
        echo "  Stripping debug symbols..."
        strip -x "$OUTPUT_LIB"

    else
        # Linux: -shared, --whole-archive for each FFI static lib
        RUST_STATIC_FLAGS=""
        if $HAS_PK; then
            RUST_STATIC_FLAGS="$RUST_STATIC_FLAGS -Wl,--whole-archive $PK_LIB -Wl,--no-whole-archive"
        fi
        if $HAS_BB; then
            RUST_STATIC_FLAGS="$RUST_STATIC_FLAGS -Wl,--whole-archive $BB_LIB -Wl,--no-whole-archive"
        fi

        # Dependent static libs from provekit build directory
        DEP_LIBS=""
        if [ -n "${PK_TARGET_DIR:-}" ] && [ -d "$PK_TARGET_DIR/build" ]; then
            while IFS= read -r -d '' lib; do
                DEP_LIBS="$DEP_LIBS $lib"
            done < <(find "$PK_TARGET_DIR/build" -name "lib*.a" -print0 2>/dev/null)
        fi

        echo "  Linking $LIB_NAME (Linux)..."
        $CC $CLANG_TARGET_FLAG \
            -shared \
            -o "$OUTPUT_LIB" \
            -Wl,--allow-multiple-definition \
            "$WORK_DIR/verity_dispatch.o" \
            $BACKEND_OBJS \
            "$WORK_DIR/verity_jni.o" \
            $RUST_STATIC_FLAGS \
            $DEP_LIBS \
            -lm -lpthread -ldl -lstdc++

        # Strip debug symbols
        echo "  Stripping debug symbols..."
        strip --strip-all "$OUTPUT_LIB"
    fi

    trap - EXIT
    rm -rf "$WORK_DIR"
    echo "  -> $OUTPUT_LIB"
    echo ""
done

echo "=== Done! ==="
echo "Native libraries are in: $OUTPUT_BASE"
find "$OUTPUT_BASE" -name "libverity_jni.*" 2>/dev/null | sort | while read -r f; do
    ls -lh "$f"
done || echo "No native libraries found — check build output above."
