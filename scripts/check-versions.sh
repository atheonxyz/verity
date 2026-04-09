#!/usr/bin/env bash
set -euo pipefail

VERSION=$(cat VERSION | tr -d '[:space:]')
ERRORS=0

check() {
  local file="$1" actual="$2" label="$3"
  if [ "$actual" != "$VERSION" ]; then
    echo "MISMATCH: $label has '$actual', expected '$VERSION' (in $file)"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: $label = $VERSION"
  fi
}

# Kotlin (Android) — Verity.kt
KT_VER=$(grep -oP 'const val VERSION = "\K[^"]+' sdks/kotlin/src/main/kotlin/xyz/atheon/verity/Verity.kt 2>/dev/null || echo "NOT_FOUND")
check "Verity.kt" "$KT_VER" "Kotlin SDK"

# Kotlin (JVM) — Verity.kt
KT_JVM_VER=$(grep -oP 'const val VERSION = "\K[^"]+' sdks/kotlin-jvm/src/main/kotlin/xyz/atheon/verity/Verity.kt 2>/dev/null || echo "NOT_FOUND")
check "Verity.kt (JVM)" "$KT_JVM_VER" "Kotlin JVM SDK"

# Swift — Verity.swift
SW_VER=$(grep -oP 'static let version = "\K[^"]+' sdks/swift/Sources/Verity/Verity.swift 2>/dev/null || echo "NOT_FOUND")
check "Verity.swift" "$SW_VER" "Swift SDK"

# JS — package.json
if [ -f sdks/js/package.json ]; then
  JS_VER=$(grep -oP '"version": "\K[^"]+' sdks/js/package.json 2>/dev/null || echo "NOT_FOUND")
  check "package.json" "$JS_VER" "JS SDK"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS version mismatch(es). Update all files to match VERSION ($VERSION)."
  exit 1
fi

echo ""
echo "All versions consistent: $VERSION"
