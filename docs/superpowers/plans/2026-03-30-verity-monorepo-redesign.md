# Verity Monorepo Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Verity ZK SDK from an iOS-first repo into a modular monorepo supporting Swift, Kotlin, and TypeScript/JavaScript with independent CI/CD publish pipelines.

**Architecture:** Shared `core/` (C dispatcher + Rust FFI backends) consumed by platform SDKs under `sdks/{swift,kotlin,js}`. Each SDK is self-contained with its own manifest, tests, and release script. CI builds core for all targets, SDK workflows consume artifacts independently.

**Tech Stack:** Swift (SPM), Kotlin (Gradle/Android), TypeScript (Node N-API + WASM), Rust (cargo), CMake (C dispatcher), GitHub Actions (CI/CD)

**Spec:** `docs/superpowers/specs/2026-03-30-verity-monorepo-redesign.md`

---

## Phase 1: Directory Restructure

### Task 1: Create directory skeleton

**Files:**
- Create: all new directories

- [ ] **Step 1: Create the full directory tree**

```bash
mkdir -p core/dispatcher/backends
mkdir -p core/include
mkdir -p core/backends/barretenberg/src
mkdir -p core/build
mkdir -p sdks/swift/Sources/Verity
mkdir -p sdks/swift/Tests/VerityTests/Fixtures
mkdir -p sdks/swift/scripts
mkdir -p sdks/kotlin/src/main/kotlin/com/atheon/verity
mkdir -p sdks/kotlin/src/main/jni
mkdir -p sdks/kotlin/src/main/jniLibs
mkdir -p sdks/kotlin/src/androidTest/kotlin/com/atheon/verity
mkdir -p sdks/kotlin/scripts
mkdir -p sdks/js/src/backends
mkdir -p sdks/js/native
mkdir -p sdks/js/wasm
mkdir -p sdks/js/tests
mkdir -p sdks/js/scripts
mkdir -p examples/ios
mkdir -p examples/android
mkdir -p examples/js/node-example
mkdir -p examples/js/browser-example
mkdir -p circuits/basic/src
mkdir -p circuits/fixtures/provekit
mkdir -p circuits/fixtures/barretenberg
mkdir -p .github/workflows
```

- [ ] **Step 2: Verify directories exist**

Run: `find . -type d -not -path './.git/*' -not -path './.omc/*' -not -path './docs/*' | sort`
Expected: all directories from step 1 listed

- [ ] **Step 3: Commit skeleton**

```bash
git add -A
git commit -m "chore: create monorepo directory skeleton"
```

---

### Task 2: Move core C dispatcher files

**Files:**
- Move: `Sources/VerityDispatch/verity_dispatch.c` → `core/dispatcher/verity_dispatch.c`
- Move: `Sources/VerityDispatch/verity_backend.h` → `core/dispatcher/verity_backend.h`
- Move: `Sources/VerityDispatch/pk_backend.c` → `core/dispatcher/backends/pk_backend.c`
- Move: `Sources/VerityDispatch/bb_backend.c` → `core/dispatcher/backends/bb_backend.c`

- [ ] **Step 1: Move dispatcher files**

```bash
cp Sources/VerityDispatch/verity_dispatch.c core/dispatcher/verity_dispatch.c
cp Sources/VerityDispatch/verity_backend.h core/dispatcher/verity_backend.h
cp Sources/VerityDispatch/pk_backend.c core/dispatcher/backends/pk_backend.c
cp Sources/VerityDispatch/bb_backend.c core/dispatcher/backends/bb_backend.c
```

- [ ] **Step 2: Update include path in verity_dispatch.c**

The file currently has `#include "verity_backend.h"` — this stays correct since `verity_backend.h` is in the same directory.

The `verity_backend.h` file has `#include "include/verity_ffi.h"` — this needs to change to `#include "../include/verity_ffi.h"` since the include directory is now at `core/include/`.

In `core/dispatcher/verity_backend.h`, change:
```c
#include "include/verity_ffi.h"
```
to:
```c
#include "../include/verity_ffi.h"
```

- [ ] **Step 3: Update include path in backend registration files**

In `core/dispatcher/backends/pk_backend.c`, change:
```c
#include "verity_backend.h"
```
to:
```c
#include "../verity_backend.h"
```

In `core/dispatcher/backends/bb_backend.c`, change:
```c
#include "verity_backend.h"
```
to:
```c
#include "../verity_backend.h"
```

- [ ] **Step 4: Verify files compile**

```bash
# Quick syntax check — does the preprocessor resolve all includes?
cc -fsyntax-only -I core/include core/dispatcher/verity_dispatch.c 2>&1 || echo "Expected: needs backend symbols (link-time)"
```

Expected: warnings about missing backend symbols (pk_*, bb_*) are fine — those come from the static libs at link time. No include errors.

- [ ] **Step 5: Commit**

```bash
git add core/dispatcher/
git commit -m "refactor: move C dispatcher to core/dispatcher/"
```

---

### Task 3: Move core include files

**Files:**
- Move: `Sources/VerityDispatch/include/verity_ffi.h` → `core/include/verity_ffi.h`
- Move: `include/verity_ffi_raw.h` → `core/include/verity_ffi_raw.h`

- [ ] **Step 1: Move header files**

```bash
cp Sources/VerityDispatch/include/verity_ffi.h core/include/verity_ffi.h
cp include/verity_ffi_raw.h core/include/verity_ffi_raw.h
```

- [ ] **Step 2: Update raw header comment**

In `core/include/verity_ffi_raw.h`, update the comment at line 4:
```c
/// The public header is Sources/VerityDispatch/include/verity_ffi.h.
```
to:
```c
/// The public header is core/include/verity_ffi.h.
```

- [ ] **Step 3: Commit**

```bash
git add core/include/
git commit -m "refactor: move public C headers to core/include/"
```

---

### Task 4: Move Rust backends

**Files:**
- Move: `zkffi/Cargo.toml` → `core/Cargo.toml`
- Move: `zkffi/backends/barretenberg/Cargo.toml` → `core/backends/barretenberg/Cargo.toml`
- Move: `zkffi/backends/barretenberg/src/lib.rs` → `core/backends/barretenberg/src/lib.rs`

- [ ] **Step 1: Copy Rust workspace**

```bash
cp zkffi/backends/barretenberg/Cargo.toml core/backends/barretenberg/Cargo.toml
cp zkffi/backends/barretenberg/src/lib.rs core/backends/barretenberg/src/lib.rs
```

- [ ] **Step 2: Create new workspace Cargo.toml**

Write `core/Cargo.toml`:
```toml
[workspace]
resolver = "2"
members = [
    "backends/barretenberg",
]
```

- [ ] **Step 3: Verify workspace resolves**

```bash
cd core && cargo metadata --no-deps --format-version 1 | head -5 && cd ..
```

Expected: shows workspace members including `barretenberg-ffi`

- [ ] **Step 4: Commit**

```bash
git add core/Cargo.toml core/backends/
git commit -m "refactor: move Rust FFI workspace to core/"
```

---

### Task 5: Move Swift SDK

**Files:**
- Move: `Sources/Verity/*.swift` → `sdks/swift/Sources/Verity/`
- Move: `Tests/VerityTests/` → `sdks/swift/Tests/VerityTests/`

- [ ] **Step 1: Copy Swift source files**

```bash
cp Sources/Verity/Verity.swift sdks/swift/Sources/Verity/
cp Sources/Verity/ProverScheme.swift sdks/swift/Sources/Verity/
cp Sources/Verity/VerifierScheme.swift sdks/swift/Sources/Verity/
cp Sources/Verity/VerityError.swift sdks/swift/Sources/Verity/
```

- [ ] **Step 2: Copy test files and fixtures**

```bash
cp Tests/VerityTests/VerityTests.swift sdks/swift/Tests/VerityTests/
cp -R Tests/VerityTests/Fixtures/* sdks/swift/Tests/VerityTests/Fixtures/
```

- [ ] **Step 3: Copy and move build scripts**

```bash
cp scripts/build-xcframework.sh sdks/swift/scripts/build-xcframework.sh
cp scripts/release.sh sdks/swift/scripts/release.sh
```

- [ ] **Step 4: Commit**

```bash
git add sdks/swift/
git commit -m "refactor: move Swift SDK to sdks/swift/"
```

---

### Task 6: Move Kotlin SDK

**Files:**
- Move: `verity-kotlin/src/` → `sdks/kotlin/src/`
- Move: `verity-kotlin/build.gradle.kts` → `sdks/kotlin/build.gradle.kts`

- [ ] **Step 1: Copy Kotlin source files**

```bash
# Main source
cp verity-kotlin/src/main/kotlin/com/aspect/verity/Verity.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/Verity.kt
cp verity-kotlin/src/main/kotlin/com/aspect/verity/Backend.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/Backend.kt
cp verity-kotlin/src/main/kotlin/com/aspect/verity/ProverScheme.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/ProverScheme.kt
cp verity-kotlin/src/main/kotlin/com/aspect/verity/VerifierScheme.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/VerifierScheme.kt
cp verity-kotlin/src/main/kotlin/com/aspect/verity/PreparedScheme.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/PreparedScheme.kt
cp verity-kotlin/src/main/kotlin/com/aspect/verity/VerityException.kt sdks/kotlin/src/main/kotlin/com/atheon/verity/VerityException.kt

# JNI bridge
cp verity-kotlin/src/main/jni/verity_jni.c sdks/kotlin/src/main/jni/verity_jni.c
```

- [ ] **Step 2: Copy build config**

```bash
cp verity-kotlin/build.gradle.kts sdks/kotlin/build.gradle.kts
```

- [ ] **Step 3: Copy test files if they exist**

```bash
if [ -d "verity-kotlin/src/androidTest" ]; then
    cp -R verity-kotlin/src/androidTest/* sdks/kotlin/src/androidTest/ 2>/dev/null || true
fi
```

- [ ] **Step 4: Commit**

```bash
git add sdks/kotlin/
git commit -m "refactor: move Kotlin SDK to sdks/kotlin/"
```

---

### Task 7: Move examples and circuits

**Files:**
- Move: `Examples/` → `examples/ios/`
- Move: `verity-kotlin/Examples/` → `examples/android/`
- Move: `noir-examples/` → `circuits/`

- [ ] **Step 1: Copy iOS examples**

```bash
cp -R Examples/BasicProof examples/ios/BasicProof
cp -R Examples/Showcase examples/ios/Showcase
```

- [ ] **Step 2: Copy Android examples**

```bash
if [ -d "verity-kotlin/Examples" ]; then
    cp -R verity-kotlin/Examples/BasicProof examples/android/BasicProof 2>/dev/null || true
    cp -R verity-kotlin/Examples/Showcase examples/android/Showcase 2>/dev/null || true
fi
```

- [ ] **Step 3: Copy circuits**

```bash
cp -R noir-examples/basic/* circuits/basic/
```

- [ ] **Step 4: Copy test fixtures**

```bash
cp Tests/VerityTests/Fixtures/circuit.json circuits/fixtures/circuit.json
cp Tests/VerityTests/Fixtures/Prover.toml circuits/fixtures/Prover.toml
cp -R Tests/VerityTests/Fixtures/provekit/* circuits/fixtures/provekit/ 2>/dev/null || true
cp -R Tests/VerityTests/Fixtures/barretenberg/* circuits/fixtures/barretenberg/ 2>/dev/null || true
```

- [ ] **Step 5: Commit**

```bash
git add examples/ circuits/
git commit -m "refactor: move examples and circuits to top-level directories"
```

---

### Task 8: Remove old directory structure

**Files:**
- Remove: `Sources/`, `Tests/`, `include/`, `verity-kotlin/`, `zkffi/`, `Examples/`, `noir-examples/`, `scripts/`, old `Package.swift`

- [ ] **Step 1: Remove old directories**

```bash
rm -rf Sources/ Tests/ include/ verity-kotlin/ zkffi/ Examples/ noir-examples/ scripts/
rm -f Package.swift
```

- [ ] **Step 2: Verify only new structure remains**

```bash
ls -la
```

Expected: `core/`, `sdks/`, `examples/`, `circuits/`, `.github/`, `docs/`, `.git/`, `.gitignore`, `README.md`, `CONTRIBUTING.md`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: remove old directory structure"
```

---

## Phase 2: Configuration & Build Files

### Task 9: Write new Package.swift for Swift SDK

**Files:**
- Create: `sdks/swift/Package.swift`

- [ ] **Step 1: Write Package.swift**

Write `sdks/swift/Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Verity",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Verity", targets: ["Verity"]),
    ],
    targets: [
        // Pre-built static library containing pk_* and bb_* symbols.
        .binaryTarget(
            name: "VerityFFI",
            url: "https://github.com/atheonxyz/verity/releases/download/v0.1.0/Verity.xcframework.zip",
            checksum: "ff6fa59c2c9b17bf95b1a7e7768583f4838aa088ebf618c082326a1ccdbcc64b"
        ),

        // C dispatcher — routes unified verity_* calls to the correct backend
        // via vtable. Contains pk_backend.c and bb_backend.c registrations.
        .target(
            name: "VerityDispatch",
            dependencies: ["VerityFFI"],
            path: "../../core/dispatcher",
            sources: [
                "verity_dispatch.c",
                "backends/pk_backend.c",
                "backends/bb_backend.c",
            ],
            publicHeadersPath: "../include",
            cSettings: [
                .headerSearchPath("../include"),
                .headerSearchPath("."),
            ]
        ),

        // Swift SDK — calls verity_* functions only (no backend-specific code).
        .target(
            name: "Verity",
            dependencies: ["VerityDispatch"],
            path: "Sources/Verity"
        ),

        .testTarget(
            name: "VerityTests",
            dependencies: ["Verity"],
            path: "Tests/VerityTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

- [ ] **Step 2: Verify Package.swift parses**

```bash
cd sdks/swift && swift package dump-package 2>&1 | head -5 && cd ../..
```

Expected: JSON output of package description (or warnings about missing binary — that's fine for now)

- [ ] **Step 3: Commit**

```bash
git add sdks/swift/Package.swift
git commit -m "feat: add new Package.swift for sdks/swift/"
```

---

### Task 10: Write new build.gradle.kts for Kotlin SDK

**Files:**
- Create: `sdks/kotlin/build.gradle.kts`

- [ ] **Step 1: Write build.gradle.kts**

Write `sdks/kotlin/build.gradle.kts`:
```kotlin
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    namespace = "com.atheon.verity"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")

        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

dependencies {
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.5.2")
}

publishing {
    publications {
        create<MavenPublication>("release") {
            groupId = "com.atheon"
            artifactId = "verity"
            version = file("../../VERSION").readText().trim()

            afterEvaluate {
                from(components["release"])
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add sdks/kotlin/build.gradle.kts
git commit -m "feat: add new build.gradle.kts for sdks/kotlin/"
```

---

### Task 11: Repackage Kotlin from com.aspect to com.atheon

**Files:**
- Modify: all `.kt` files under `sdks/kotlin/src/main/kotlin/com/atheon/verity/`
- Modify: `sdks/kotlin/src/main/jni/verity_jni.c`

- [ ] **Step 1: Update package declarations in all Kotlin files**

In each of these files, replace the first line `package com.aspect.verity` with `package com.atheon.verity`:

- `sdks/kotlin/src/main/kotlin/com/atheon/verity/Verity.kt`
- `sdks/kotlin/src/main/kotlin/com/atheon/verity/Backend.kt`
- `sdks/kotlin/src/main/kotlin/com/atheon/verity/ProverScheme.kt`
- `sdks/kotlin/src/main/kotlin/com/atheon/verity/VerifierScheme.kt`
- `sdks/kotlin/src/main/kotlin/com/atheon/verity/PreparedScheme.kt`
- `sdks/kotlin/src/main/kotlin/com/atheon/verity/VerityException.kt`

For each file, replace:
```kotlin
package com.aspect.verity
```
with:
```kotlin
package com.atheon.verity
```

- [ ] **Step 2: Update JNI function names in verity_jni.c**

JNI function names encode the Java package path. In `sdks/kotlin/src/main/jni/verity_jni.c`, replace all occurrences of `com_aspect_verity` with `com_atheon_verity`. This affects every `JNIEXPORT` function name and the `FindClass` call.

Replace all occurrences of `com/aspect/verity` with `com/atheon/verity` (for FindClass paths).
Replace all occurrences of `Java_com_aspect_verity` with `Java_com_atheon_verity` (for JNI function names).

Specifically the FindClass call:
```c
jclass cls = (*env)->FindClass(env, "com/aspect/verity/VerityException");
```
becomes:
```c
jclass cls = (*env)->FindClass(env, "com/atheon/verity/VerityException");
```

And the fromCode method signature path:
```c
"(I)Lcom/aspect/verity/VerityException;"
```
becomes:
```c
"(I)Lcom/atheon/verity/VerityException;"
```

All `Java_com_aspect_verity_Verity_native*` function names become `Java_com_atheon_verity_Verity_native*`.

- [ ] **Step 3: Update JNI header include path**

In `sdks/kotlin/src/main/jni/verity_jni.c`, the `#include "verity_ffi.h"` needs to resolve. Add a note that the build system must pass `-I../../core/include` or copy the header. For now update the include:
```c
#include "verity_ffi.h"
```
This stays the same — the Gradle CMake/ndk-build config will set the include path.

- [ ] **Step 4: Commit**

```bash
git add sdks/kotlin/
git commit -m "refactor: repackage Kotlin SDK from com.aspect to com.atheon"
```

---

### Task 12: Create CMakeLists.txt for C dispatcher

**Files:**
- Create: `core/dispatcher/CMakeLists.txt`

- [ ] **Step 1: Write CMakeLists.txt**

Write `core/dispatcher/CMakeLists.txt`:
```cmake
cmake_minimum_required(VERSION 3.14)
project(verity_dispatch C)

add_library(verity_dispatch STATIC
    verity_dispatch.c
    backends/pk_backend.c
    backends/bb_backend.c
)

target_include_directories(verity_dispatch
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/../include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
)

# Backend symbols (pk_*, bb_*) are resolved at link time from
# the pre-built static libraries (xcframework, .so, etc.).
# No additional link targets needed here.
```

- [ ] **Step 2: Commit**

```bash
git add core/dispatcher/CMakeLists.txt
git commit -m "feat: add CMakeLists.txt for C dispatcher"
```

---

### Task 13: Create backend manifest

**Files:**
- Create: `core/backends/barretenberg/backend.toml`

- [ ] **Step 1: Write backend.toml**

Write `core/backends/barretenberg/backend.toml`:
```toml
[backend]
name = "barretenberg"
id = 1
description = "UltraHonk proving system with KZG commitments"

[targets.ios]
type = "rust-ffi"

[targets.android]
type = "rust-ffi"

[targets.node]
type = "rust-ffi"

[targets.wasm]
type = "vendor"
package = "@aztec/bb.js"
adapter = "sdks/js/src/backends/barretenberg.ts"
```

- [ ] **Step 2: Commit**

```bash
git add core/backends/barretenberg/backend.toml
git commit -m "feat: add backend capability manifest for barretenberg"
```

---

### Task 14: Create VERSION file and Makefile

**Files:**
- Create: `VERSION`
- Create: `Makefile`

- [ ] **Step 1: Write VERSION**

Write `VERSION`:
```
0.2.0
```

- [ ] **Step 2: Write Makefile**

Write `Makefile`:
```makefile
VERSION := $(shell cat VERSION)

# ── Core builds ────────────────────────────────────────────────────────

.PHONY: core-ios core-android core-wasm core-native core-all

core-ios:
	bash core/build/build-ios.sh

core-android:
	bash core/build/build-android.sh

core-wasm:
	bash core/build/build-wasm.sh

core-native:
	bash core/build/build-native.sh

core-all: core-ios core-android core-wasm core-native

# ── SDK tests ──────────────────────────────────────────────────────────

.PHONY: test-swift test-kotlin test-js test-all

test-swift: core-ios
	cd sdks/swift && xcodebuild test \
		-scheme Verity \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-skipPackagePluginValidation

test-kotlin: core-android
	cd sdks/kotlin && ./gradlew connectedAndroidTest

test-js: core-wasm core-native
	cd sdks/js && npm test

test-all: test-swift test-kotlin test-js

# ── Releases ───────────────────────────────────────────────────────────

.PHONY: release-swift release-kotlin release-js

release-swift: core-ios
	bash sdks/swift/scripts/release.sh $(VERSION)

release-kotlin: core-android
	bash sdks/kotlin/scripts/release.sh $(VERSION)

release-js: core-wasm core-native
	bash sdks/js/scripts/release.sh $(VERSION)

# ── Utilities ──────────────────────────────────────────────────────────

.PHONY: clean

clean:
	rm -rf core/target
	rm -rf sdks/swift/.build sdks/swift/output
	cd sdks/kotlin && ./gradlew clean 2>/dev/null || true
	cd sdks/js && rm -rf node_modules dist 2>/dev/null || true
```

- [ ] **Step 3: Commit**

```bash
git add VERSION Makefile
git commit -m "feat: add VERSION file and top-level Makefile"
```

---

### Task 15: Create core build scripts

**Files:**
- Create: `core/build/build-ios.sh`
- Create: `core/build/build-android.sh`
- Create: `core/build/build-wasm.sh`
- Create: `core/build/build-native.sh`

- [ ] **Step 1: Write build-ios.sh**

Write `core/build/build-ios.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Build core libraries for iOS (device + simulator).
#
# Usage:
#   bash core/build/build-ios.sh <provekit-path>
#   bash core/build/build-ios.sh ../provekit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"

IOS_DEVICE="aarch64-apple-ios"
IOS_SIM="aarch64-apple-ios-sim"

if [ $# -lt 1 ]; then
    echo "Usage: bash core/build/build-ios.sh <provekit-path>"
    exit 1
fi

PROVEKIT_ROOT="$(cd "$1" && pwd)"

if [ ! -f "$PROVEKIT_ROOT/Cargo.toml" ]; then
    echo "ERROR: Cannot find provekit repo at $PROVEKIT_ROOT"
    exit 1
fi

echo "=== Building Verity core for iOS ==="
echo "Core dir:      $CORE_DIR"
echo "ProveKit root: $PROVEKIT_ROOT"

rustup target add "$IOS_DEVICE" "$IOS_SIM" 2>/dev/null || true

# Build provekit-ffi
pushd "$PROVEKIT_ROOT" > /dev/null
echo "Building provekit-ffi for $IOS_DEVICE..."
cargo build --release --target "$IOS_DEVICE" -p provekit-ffi
echo "Building provekit-ffi for $IOS_SIM..."
cargo build --release --target "$IOS_SIM" -p provekit-ffi
popd > /dev/null

# Build all core backends
pushd "$CORE_DIR" > /dev/null
echo "Building core backends for $IOS_DEVICE..."
cargo build --release --target "$IOS_DEVICE"
echo "Building core backends for $IOS_SIM..."
cargo build --release --target "$IOS_SIM"
popd > /dev/null

# Merge static libs
echo "Merging static libraries..."
MERGED_DIR=$(mktemp -d)
mkdir -p "$MERGED_DIR/ios-arm64" "$MERGED_DIR/ios-arm64-sim"

ZK_FFI_LIBS_DEVICE=$(find "$CORE_DIR/target/$IOS_DEVICE/release" -maxdepth 1 -name "lib*.a" -type f)
ZK_FFI_LIBS_SIM=$(find "$CORE_DIR/target/$IOS_SIM/release" -maxdepth 1 -name "lib*.a" -type f)

libtool -static -o "$MERGED_DIR/ios-arm64/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_DEVICE/release/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_DEVICE

libtool -static -o "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    "$PROVEKIT_ROOT/target/$IOS_SIM/release/libprovekit_ffi.a" \
    $ZK_FFI_LIBS_SIM

# Create headers + modulemap
HEADERS_DIR=$(mktemp -d)
cp "$CORE_DIR/include/verity_ffi_raw.h" "$HEADERS_DIR/verity_ffi_raw.h"
cat > "$HEADERS_DIR/module.modulemap" <<'MODULEMAP'
module VerityFFI {
    header "verity_ffi_raw.h"
    link "verity"
    export *
}
MODULEMAP

# Create xcframework
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/Verity.xcframework"

echo "Creating xcframework..."
xcodebuild -create-xcframework \
    -library "$MERGED_DIR/ios-arm64/libverity.a" \
    -headers "$HEADERS_DIR" \
    -library "$MERGED_DIR/ios-arm64-sim/libverity.a" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/Verity.xcframework"

rm -rf "$HEADERS_DIR" "$MERGED_DIR"

echo "=== Done: $OUTPUT_DIR/Verity.xcframework ==="
```

- [ ] **Step 2: Write build-android.sh**

Write `core/build/build-android.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Build core libraries for Android (arm64-v8a + x86_64).
#
# Requires: Android NDK, Rust with android targets

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/android"

ANDROID_ARM64="aarch64-linux-android"
ANDROID_X86="x86_64-linux-android"

echo "=== Building Verity core for Android ==="

rustup target add "$ANDROID_ARM64" "$ANDROID_X86" 2>/dev/null || true

pushd "$CORE_DIR" > /dev/null

echo "Building for $ANDROID_ARM64..."
cargo build --release --target "$ANDROID_ARM64"

echo "Building for $ANDROID_X86..."
cargo build --release --target "$ANDROID_X86"

popd > /dev/null

# Copy .so files to output
mkdir -p "$OUTPUT_DIR/arm64-v8a" "$OUTPUT_DIR/x86_64"

find "$CORE_DIR/target/$ANDROID_ARM64/release" -maxdepth 1 -name "*.so" -exec cp {} "$OUTPUT_DIR/arm64-v8a/" \;
find "$CORE_DIR/target/$ANDROID_X86/release" -maxdepth 1 -name "*.so" -exec cp {} "$OUTPUT_DIR/x86_64/" \;

echo "=== Done: $OUTPUT_DIR ==="
```

- [ ] **Step 3: Write build-wasm.sh**

Write `core/build/build-wasm.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Build core libraries for WASM (browser target).
#
# Requires: wasm-pack (cargo install wasm-pack)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output/wasm"

echo "=== Building Verity core for WASM ==="

# Only build backends that support wasm (check backend.toml)
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
```

- [ ] **Step 4: Write build-native.sh**

Write `core/build/build-native.sh`:
```bash
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
```

- [ ] **Step 5: Make scripts executable**

```bash
chmod +x core/build/build-ios.sh
chmod +x core/build/build-android.sh
chmod +x core/build/build-wasm.sh
chmod +x core/build/build-native.sh
```

- [ ] **Step 6: Commit**

```bash
git add core/build/
git commit -m "feat: add core build scripts for all targets"
```

---

### Task 16: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Write updated .gitignore**

Write `.gitignore`:
```gitignore
# Build outputs
output/
core/target/

# Swift
sdks/swift/.build/
sdks/swift/DerivedData/
*.xcuserstate
xcuserdata/
.swiftpm/

# Android / Gradle
.gradle/
.idea/
build/
local.properties
*.so

# Kotlin
sdks/kotlin/build/

# JavaScript / Node
sdks/js/node_modules/
sdks/js/dist/
*.node

# Rust
target/

# OS
.DS_Store
*.o

# Examples (Xcode projects are generated)
examples/ios/BasicProof/*.xcodeproj/
examples/ios/Showcase/*.xcodeproj/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: update .gitignore for monorepo structure"
```

---

## Phase 3: TypeScript/JavaScript SDK

### Task 17: Create JS SDK package configuration

**Files:**
- Create: `sdks/js/package.json`
- Create: `sdks/js/tsconfig.json`

- [ ] **Step 1: Write package.json**

Write `sdks/js/package.json`:
```json
{
  "name": "@atheon/verity",
  "version": "0.2.0",
  "description": "Zero-knowledge proof SDK for Node.js and browsers",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/atheonxyz/verity",
    "directory": "sdks/js"
  },
  "type": "module",
  "main": "./dist/node/index.js",
  "module": "./dist/browser/index.js",
  "types": "./dist/types/index.d.ts",
  "exports": {
    ".": {
      "node": {
        "import": "./dist/node/index.js",
        "require": "./dist/node/index.cjs"
      },
      "browser": {
        "import": "./dist/browser/index.js"
      },
      "default": "./dist/browser/index.js"
    }
  },
  "files": [
    "dist/",
    "README.md"
  ],
  "scripts": {
    "build": "tsup",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "tsc --noEmit",
    "prepublishOnly": "npm run build"
  },
  "devDependencies": {
    "tsup": "^8.0.0",
    "typescript": "^5.4.0",
    "vitest": "^2.0.0"
  }
}
```

- [ ] **Step 2: Write tsconfig.json**

Write `sdks/js/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationDir": "./dist/types",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "sourceMap": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [ ] **Step 3: Commit**

```bash
git add sdks/js/package.json sdks/js/tsconfig.json
git commit -m "feat: add JS SDK package configuration"
```

---

### Task 18: Create JS SDK type definitions and errors

**Files:**
- Create: `sdks/js/src/types.ts`
- Create: `sdks/js/src/errors.ts`

- [ ] **Step 1: Write types.ts**

Write `sdks/js/src/types.ts`:
```typescript
/** Available proving backends. */
export enum Backend {
  /** ProveKit WHIR backend (transparent, hash-based). */
  ProveKit = 0,
  /** Barretenberg UltraHonk backend (KZG commitments). */
  Barretenberg = 1,
}

/** Opaque handle to a compiled prover scheme. */
export interface ProverScheme {
  /** Save the prover scheme to a file (Node.js only). */
  save(path: string): Promise<void>;
  /** Serialize the prover scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release native resources. */
  dispose(): void;
}

/** Opaque handle to a compiled verifier scheme. */
export interface VerifierScheme {
  /** Save the verifier scheme to a file (Node.js only). */
  save(path: string): Promise<void>;
  /** Serialize the verifier scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release native resources. */
  dispose(): void;
}

/** Result of prepare() — holds both prover and verifier schemes. */
export interface PreparedScheme {
  readonly prover: ProverScheme;
  readonly verifier: VerifierScheme;
  /** Dispose both schemes. */
  dispose(): void;
}

/** Backend binding interface — implemented per runtime (Node/WASM). */
export interface BackendBinding {
  init(): Promise<void>;
  prepare(circuit: string | Uint8Array): Promise<{ prover: ProverScheme; verifier: VerifierScheme }>;
  prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array>;
  verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean>;
  loadProver(data: Uint8Array): Promise<ProverScheme>;
  loadVerifier(data: Uint8Array): Promise<VerifierScheme>;
}
```

- [ ] **Step 2: Write errors.ts**

Write `sdks/js/src/errors.ts`:
```typescript
/** Error codes matching the C FFI VerityError enum. */
export enum VerityErrorCode {
  NOT_INITIALIZED = -1,
  INVALID_INPUT = 1,
  SCHEME_READ_ERROR = 2,
  WITNESS_READ_ERROR = 3,
  PROOF_ERROR = 4,
  SERIALIZATION_ERROR = 5,
  UTF8_ERROR = 6,
  FILE_WRITE_ERROR = 7,
  COMPILATION_ERROR = 8,
  UNKNOWN_BACKEND = 9,
  BACKEND_UNAVAILABLE = 10,
}

/** Typed error for Verity operations. */
export class VerityError extends Error {
  readonly code: VerityErrorCode;

  constructor(code: VerityErrorCode, detail?: string) {
    const message = detail
      ? `${VerityError.messageForCode(code)}: ${detail}`
      : VerityError.messageForCode(code);
    super(message);
    this.name = "VerityError";
    this.code = code;
  }

  private static messageForCode(code: VerityErrorCode): string {
    switch (code) {
      case VerityErrorCode.NOT_INITIALIZED:
        return "Verity not initialized";
      case VerityErrorCode.INVALID_INPUT:
        return "Invalid input";
      case VerityErrorCode.SCHEME_READ_ERROR:
        return "Failed to read scheme/circuit file";
      case VerityErrorCode.WITNESS_READ_ERROR:
        return "Witness read error";
      case VerityErrorCode.PROOF_ERROR:
        return "Proof generation or verification error";
      case VerityErrorCode.SERIALIZATION_ERROR:
        return "Serialization error";
      case VerityErrorCode.UTF8_ERROR:
        return "UTF-8 error";
      case VerityErrorCode.FILE_WRITE_ERROR:
        return "File write error";
      case VerityErrorCode.COMPILATION_ERROR:
        return "Circuit compilation error";
      case VerityErrorCode.UNKNOWN_BACKEND:
        return "Unknown or unregistered backend";
      case VerityErrorCode.BACKEND_UNAVAILABLE:
        return "Backend not available in this runtime";
      default:
        return `FFI error code: ${code}`;
    }
  }

  /** Map an FFI error code to a VerityError. */
  static fromCode(code: number, detail?: string): VerityError {
    return new VerityError(code as VerityErrorCode, detail);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add sdks/js/src/types.ts sdks/js/src/errors.ts
git commit -m "feat: add JS SDK type definitions and error handling"
```

---

### Task 19: Create JS SDK core Verity class

**Files:**
- Create: `sdks/js/src/verity.ts`
- Create: `sdks/js/src/index.ts`

- [ ] **Step 1: Write verity.ts**

Write `sdks/js/src/verity.ts`:
```typescript
import { Backend, type BackendBinding, type PreparedScheme, type ProverScheme, type VerifierScheme } from "./types.js";
import { VerityError, VerityErrorCode } from "./errors.js";

/**
 * Verity — generate and verify zero-knowledge proofs.
 *
 * Usage:
 * ```ts
 * const verity = await Verity.create(Backend.Barretenberg);
 * const scheme = await verity.prepare(circuitJSON);
 * const proof = await verity.prove(scheme.prover, { a: 1, b: 2 });
 * const valid = await verity.verify(scheme.verifier, proof);
 * ```
 */
export class Verity {
  private binding: BackendBinding;
  private _backend: Backend;

  private constructor(backend: Backend, binding: BackendBinding) {
    this._backend = backend;
    this.binding = binding;
  }

  /** The backend this instance was created with. */
  get backend(): Backend {
    return this._backend;
  }

  /**
   * Create a Verity instance with the specified backend.
   * Initializes the backend (may load WASM or native addon).
   */
  static async create(backend: Backend): Promise<Verity> {
    const binding = await Verity.resolveBinding(backend);
    await binding.init();
    return new Verity(backend, binding);
  }

  private static async resolveBinding(backend: Backend): Promise<BackendBinding> {
    // Dynamic import based on runtime — resolved at build time via package.json exports
    throw new VerityError(
      VerityErrorCode.BACKEND_UNAVAILABLE,
      `Backend ${Backend[backend]} binding not yet implemented`
    );
  }

  /** Compile a circuit into prover + verifier schemes. */
  async prepare(circuit: string | Uint8Array): Promise<PreparedScheme> {
    const { prover, verifier } = await this.binding.prepare(circuit);
    return {
      prover,
      verifier,
      dispose() {
        prover.dispose();
        verifier.dispose();
      },
    };
  }

  /** Generate a proof. */
  async prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array> {
    return this.binding.prove(prover, inputs);
  }

  /** Verify a proof. Returns true if valid. */
  async verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean> {
    return this.binding.verify(verifier, proof);
  }

  /** Load a prover scheme from bytes. */
  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    return this.binding.loadProver(data);
  }

  /** Load a verifier scheme from bytes. */
  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    return this.binding.loadVerifier(data);
  }
}
```

- [ ] **Step 2: Write index.ts**

Write `sdks/js/src/index.ts`:
```typescript
export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, PreparedScheme, BackendBinding } from "./types.js";
export { VerityError, VerityErrorCode } from "./errors.js";
```

- [ ] **Step 3: Commit**

```bash
git add sdks/js/src/verity.ts sdks/js/src/index.ts
git commit -m "feat: add JS SDK core Verity class and entry point"
```

---

### Task 20: Create JS SDK backend binding stubs

**Files:**
- Create: `sdks/js/src/node.ts`
- Create: `sdks/js/src/browser.ts`
- Create: `sdks/js/src/backends/barretenberg.ts`

- [ ] **Step 1: Write node.ts stub**

Write `sdks/js/src/node.ts`:
```typescript
/**
 * Node.js entry point — uses N-API native addon for FFI.
 *
 * The native addon (verity_napi.node) provides synchronous bindings
 * to the C dispatcher, wrapped in async for API consistency.
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, PreparedScheme } from "./types.js";
export { VerityError, VerityErrorCode } from "./errors.js";

// TODO: Wire up N-API binding in Verity.resolveBinding()
// The native addon will be built from native/verity_napi.c
```

- [ ] **Step 2: Write browser.ts stub**

Write `sdks/js/src/browser.ts`:
```typescript
/**
 * Browser entry point — uses WASM or vendor JS for proving backends.
 *
 * Each backend provides its own WASM binding (compiled from Rust)
 * or wraps a vendor JS package (e.g., @aztec/bb.js for Barretenberg).
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, PreparedScheme } from "./types.js";
export { VerityError, VerityErrorCode } from "./errors.js";

// TODO: Wire up WASM/vendor bindings in Verity.resolveBinding()
```

- [ ] **Step 3: Write barretenberg backend adapter stub**

Write `sdks/js/src/backends/barretenberg.ts`:
```typescript
import type { BackendBinding, ProverScheme, VerifierScheme } from "../types.js";

/**
 * Barretenberg backend adapter for browser (WASM).
 *
 * Wraps @aztec/bb.js to provide the standard BackendBinding interface.
 * For Node.js, the native addon handles Barretenberg directly via the
 * C dispatcher — this adapter is browser-only.
 */
export class BarretenbergBinding implements BackendBinding {
  async init(): Promise<void> {
    // TODO: Import and initialize @aztec/bb.js
    throw new Error("Barretenberg WASM binding not yet implemented");
  }

  async prepare(circuit: string | Uint8Array): Promise<{ prover: ProverScheme; verifier: VerifierScheme }> {
    throw new Error("Not implemented");
  }

  async prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array> {
    throw new Error("Not implemented");
  }

  async verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean> {
    throw new Error("Not implemented");
  }

  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    throw new Error("Not implemented");
  }

  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    throw new Error("Not implemented");
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add sdks/js/src/node.ts sdks/js/src/browser.ts sdks/js/src/backends/
git commit -m "feat: add JS SDK runtime entry points and backend adapter stubs"
```

---

### Task 21: Create JS SDK N-API bridge stub

**Files:**
- Create: `sdks/js/native/verity_napi.c`
- Create: `sdks/js/native/binding.gyp`

- [ ] **Step 1: Write verity_napi.c stub**

Write `sdks/js/native/verity_napi.c`:
```c
/**
 * N-API bridge between Node.js and Verity FFI.
 *
 * Similar to verity_jni.c but for Node.js. Uses N-API for ABI stability.
 * Build with node-gyp or prebuildify.
 */

#include <node_api.h>
#include "verity_ffi.h"

/* ── Helpers ─────────────────────────────────────────────────────────── */

static napi_value throw_verity_error(napi_env env, int code) {
    const char *msg;
    switch (code) {
        case VERITY_INVALID_INPUT:      msg = "Invalid input"; break;
        case VERITY_SCHEME_READ_ERROR:  msg = "Scheme read error"; break;
        case VERITY_PROOF_ERROR:        msg = "Proof error"; break;
        case VERITY_SERIALIZATION_ERROR: msg = "Serialization error"; break;
        case VERITY_COMPILATION_ERROR:  msg = "Compilation error"; break;
        case VERITY_UNKNOWN_BACKEND:    msg = "Unknown backend"; break;
        default:                        msg = "FFI error"; break;
    }
    napi_throw_error(env, NULL, msg);
    return NULL;
}

/* ── Init ────────────────────────────────────────────────────────────── */

static napi_value napi_verity_init(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, NULL, NULL);

    int32_t backend;
    napi_get_value_int32(env, argv[0], &backend);

    int code = verity_init((VerityBackend)backend);
    if (code != 0) return throw_verity_error(env, code);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

/* ── Module registration ─────────────────────────────────────────────── */

static napi_value init_module(napi_env env, napi_value exports) {
    napi_property_descriptor props[] = {
        { "init", NULL, napi_verity_init, NULL, NULL, NULL, napi_default, NULL },
        /* TODO: Add prepare, prove, verify, load, save, serialize, free */
    };

    napi_define_properties(env, exports, sizeof(props) / sizeof(props[0]), props);
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init_module)
```

- [ ] **Step 2: Write binding.gyp**

Write `sdks/js/native/binding.gyp`:
```json
{
  "targets": [
    {
      "target_name": "verity_napi",
      "sources": ["verity_napi.c"],
      "include_dirs": ["../../../core/include"],
      "conditions": [
        ["OS=='mac'", {
          "libraries": [
            "-L../../../core/target/release",
            "-lbarretenberg_ffi"
          ]
        }],
        ["OS=='linux'", {
          "libraries": [
            "-L../../../core/target/release",
            "-lbarretenberg_ffi"
          ]
        }]
      ]
    }
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add sdks/js/native/
git commit -m "feat: add N-API bridge stub for Node.js"
```

---

### Task 22: Create JS SDK WASM wrapper stub

**Files:**
- Create: `sdks/js/wasm/verity_wasm.rs`
- Create: `sdks/js/wasm/Cargo.toml`

- [ ] **Step 1: Write Cargo.toml**

Write `sdks/js/wasm/Cargo.toml`:
```toml
[package]
name = "verity-wasm"
version = "0.2.0"
edition = "2021"
description = "WASM bindings for Verity ZK proof SDK"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = { version = "0.3", features = ["console"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

- [ ] **Step 2: Write verity_wasm.rs stub**

Write `sdks/js/wasm/verity_wasm.rs`:
```rust
//! WASM bindings for Verity — wraps Rust FFI backends that compile to WASM.
//!
//! For backends that provide vendor WASM (like Barretenberg via @aztec/bb.js),
//! the JS adapter in src/backends/ handles it directly. This crate is only
//! for backends whose Rust code compiles cleanly to wasm32-unknown-unknown.

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn verity_wasm_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// TODO: Implement WASM bindings for backends that support rust-wasm target type.
// Each backend that declares [targets.wasm] type = "rust-wasm" in its backend.toml
// will be compiled into this crate and exposed via wasm-bindgen.
```

- [ ] **Step 3: Commit**

```bash
git add sdks/js/wasm/
git commit -m "feat: add WASM wrapper stub for browser builds"
```

---

### Task 23: Create JS SDK test skeleton

**Files:**
- Create: `sdks/js/tests/verity.test.ts`

- [ ] **Step 1: Write test skeleton**

Write `sdks/js/tests/verity.test.ts`:
```typescript
import { describe, it, expect } from "vitest";
import { Backend, VerityError, VerityErrorCode } from "../src/index.js";

describe("Verity JS SDK", () => {
  describe("types", () => {
    it("should export Backend enum with correct values", () => {
      expect(Backend.ProveKit).toBe(0);
      expect(Backend.Barretenberg).toBe(1);
    });
  });

  describe("errors", () => {
    it("should create VerityError from code", () => {
      const err = VerityError.fromCode(1, "test detail");
      expect(err).toBeInstanceOf(VerityError);
      expect(err.code).toBe(VerityErrorCode.INVALID_INPUT);
      expect(err.message).toContain("Invalid input");
      expect(err.message).toContain("test detail");
    });

    it("should create VerityError for backend unavailable", () => {
      const err = new VerityError(VerityErrorCode.BACKEND_UNAVAILABLE);
      expect(err.code).toBe(VerityErrorCode.BACKEND_UNAVAILABLE);
      expect(err.message).toContain("Backend not available");
    });
  });

  // Integration tests require native addon or WASM — skipped until bindings are wired.
  // describe("integration", () => {
  //   it("should prepare, prove, and verify", async () => { ... });
  // });
});
```

- [ ] **Step 2: Commit**

```bash
git add sdks/js/tests/
git commit -m "feat: add JS SDK test skeleton"
```

---

## Phase 4: CI/CD Pipelines

### Task 24: Create core build workflow

**Files:**
- Create: `.github/workflows/core-build.yml`

- [ ] **Step 1: Write core-build.yml**

Write `.github/workflows/core-build.yml`:
```yaml
name: Core Build

on:
  workflow_call:
    inputs:
      targets:
        description: "Comma-separated targets: ios,android,wasm,native"
        required: false
        default: "ios,android,wasm,native"
        type: string
  push:
    paths:
      - "core/**"
  pull_request:
    paths:
      - "core/**"

jobs:
  build-ios:
    if: contains(inputs.targets || 'ios', 'ios')
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@nightly
        with:
          targets: aarch64-apple-ios,aarch64-apple-ios-sim
      - uses: actions/cache@v4
        with:
          path: core/target
          key: rust-ios-${{ hashFiles('core/Cargo.lock') }}
      - name: Build for iOS
        run: |
          cd core
          cargo build --release --target aarch64-apple-ios
          cargo build --release --target aarch64-apple-ios-sim
      - uses: actions/upload-artifact@v4
        with:
          name: core-ios
          path: core/target/*/release/lib*.a

  build-android:
    if: contains(inputs.targets || 'android', 'android')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@nightly
        with:
          targets: aarch64-linux-android,x86_64-linux-android
      - uses: actions/cache@v4
        with:
          path: core/target
          key: rust-android-${{ hashFiles('core/Cargo.lock') }}
      - name: Build for Android
        run: bash core/build/build-android.sh
      - uses: actions/upload-artifact@v4
        with:
          name: core-android
          path: output/android/

  build-wasm:
    if: contains(inputs.targets || 'wasm', 'wasm')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@nightly
        with:
          targets: wasm32-unknown-unknown
      - name: Install wasm-pack
        run: cargo install wasm-pack
      - uses: actions/cache@v4
        with:
          path: core/target
          key: rust-wasm-${{ hashFiles('core/Cargo.lock') }}
      - name: Build for WASM
        run: bash core/build/build-wasm.sh
      - uses: actions/upload-artifact@v4
        with:
          name: core-wasm
          path: output/wasm/

  build-native:
    if: contains(inputs.targets || 'native', 'native')
    strategy:
      matrix:
        os: [macos-14, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@nightly
      - uses: actions/cache@v4
        with:
          path: core/target
          key: rust-native-${{ matrix.os }}-${{ hashFiles('core/Cargo.lock') }}
      - name: Build for host
        run: bash core/build/build-native.sh
      - uses: actions/upload-artifact@v4
        with:
          name: core-native-${{ matrix.os }}
          path: core/target/release/lib*.a
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/core-build.yml
git commit -m "feat: add core build CI workflow"
```

---

### Task 25: Create SDK CI workflows

**Files:**
- Create: `.github/workflows/sdk-swift.yml`
- Create: `.github/workflows/sdk-kotlin.yml`
- Create: `.github/workflows/sdk-js.yml`

- [ ] **Step 1: Write sdk-swift.yml**

Write `.github/workflows/sdk-swift.yml`:
```yaml
name: Swift SDK

on:
  push:
    paths:
      - "sdks/swift/**"
      - "core/**"
  pull_request:
    paths:
      - "sdks/swift/**"
      - "core/**"
  release:
    types: [published]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build and test
        run: |
          cd sdks/swift
          xcodebuild test \
            -scheme Verity \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -skipPackagePluginValidation

  publish:
    needs: test
    if: github.event_name == 'release'
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Release
        run: bash sdks/swift/scripts/release.sh ${{ github.event.release.tag_name }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 2: Write sdk-kotlin.yml**

Write `.github/workflows/sdk-kotlin.yml`:
```yaml
name: Kotlin SDK

on:
  push:
    paths:
      - "sdks/kotlin/**"
      - "core/**"
  pull_request:
    paths:
      - "sdks/kotlin/**"
      - "core/**"
  release:
    types: [published]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - name: Build
        run: cd sdks/kotlin && ./gradlew build

  publish:
    needs: test
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - name: Publish to Maven Central
        run: cd sdks/kotlin && ./gradlew publish
        env:
          ORG_GRADLE_PROJECT_signingKey: ${{ secrets.GPG_SIGNING_KEY }}
          ORG_GRADLE_PROJECT_signingPassword: ${{ secrets.GPG_PASSPHRASE }}
          ORG_GRADLE_PROJECT_sonatypeUsername: ${{ secrets.SONATYPE_USERNAME }}
          ORG_GRADLE_PROJECT_sonatypePassword: ${{ secrets.SONATYPE_PASSWORD }}
```

- [ ] **Step 3: Write sdk-js.yml**

Write `.github/workflows/sdk-js.yml`:
```yaml
name: JS SDK

on:
  push:
    paths:
      - "sdks/js/**"
      - "core/**"
  pull_request:
    paths:
      - "sdks/js/**"
      - "core/**"
  release:
    types: [published]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org
      - name: Install and test
        run: |
          cd sdks/js
          npm install
          npm run lint
          npm test

  publish:
    needs: test
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org
      - name: Publish to npm
        run: |
          cd sdks/js
          npm install
          npm run build
          npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/sdk-swift.yml .github/workflows/sdk-kotlin.yml .github/workflows/sdk-js.yml
git commit -m "feat: add CI/CD workflows for Swift, Kotlin, and JS SDKs"
```

---

## Phase 5: Documentation

### Task 26: Write new README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write README.md**

Write `README.md`:
```markdown
# Verity SDK

Zero-knowledge proof SDK for iOS, Android, and JavaScript. Supports multiple proving backends with a single, unified API.

## Install

### Swift (iOS / macOS)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/atheonxyz/verity", from: "0.2.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Verity", package: "verity")
    ])
]
```

### Kotlin (Android)

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.atheon:verity:0.2.0")
}
```

### TypeScript / JavaScript

```bash
npm install @atheon/verity
```

## Quick Start

### Swift

```swift
import Verity

let verity = try Verity(backend: .provekit)
let scheme = try verity.prepare(circuit: "circuit.json")
let proof  = try verity.prove(with: scheme.prover, input: "Prover.toml")
let valid  = try verity.verify(with: scheme.verifier, proof: proof)
```

### Kotlin

```kotlin
import com.atheon.verity.*

val verity = Verity(Backend.PROVEKIT)
val scheme = verity.prepare("circuit.json")
val proof  = verity.prove(scheme.prover, "Prover.toml")
val valid  = verity.verify(scheme.verifier, proof)
scheme.close()
```

### TypeScript

```typescript
import { Verity, Backend } from '@atheon/verity';

const verity = await Verity.create(Backend.Barretenberg);
const scheme = await verity.prepare(circuitJSON);
const proof  = await verity.prove(scheme.prover, { a: 1, b: 2 });
const valid  = await verity.verify(scheme.verifier, proof);
scheme.dispose();
```

## Backends

| Backend | Enum | Trusted Setup | Proof Size |
|---------|------|---------------|------------|
| ProveKit (WHIR) | `.provekit` / `PROVEKIT` / `ProveKit` | None (transparent) | Variable (~KBs) |
| Barretenberg (UltraHonk) | `.barretenberg` / `BARRETENBERG` / `Barretenberg` | Universal (auto) | Several KB |

Switching backends changes one line. The rest of your code stays identical.

## Repo Structure

```
verity/
├── core/           # Shared C dispatcher + Rust FFI backends
├── sdks/
│   ├── swift/      # iOS SDK (Swift Package Manager)
│   ├── kotlin/     # Android SDK (Gradle / Maven)
│   └── js/         # JS SDK (npm, Node + browser)
├── examples/       # Platform-specific demo apps
├── circuits/       # Noir test circuits and fixtures
└── docs/           # Architecture, guides, roadmap
```

## Docs

- [Architecture](docs/architecture.md) — how core + SDKs fit together
- [Adding a Backend](docs/adding-a-backend.md) — contribute a new ZK backend
- [Adding an SDK](docs/adding-an-sdk.md) — add support for a new platform
- [Building & Testing](docs/building.md) — developer setup
- [Roadmap](docs/roadmap.md) — what's next

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for multi-platform monorepo"
```

---

### Task 27: Write architecture documentation

**Files:**
- Create: `docs/architecture.md`

- [ ] **Step 1: Write architecture.md**

Write `docs/architecture.md`:
```markdown
# Architecture

## Overview

Verity is a multi-platform ZK proof SDK. The architecture has two layers:

1. **Core** (`core/`) — shared C dispatcher + Rust FFI backends
2. **SDKs** (`sdks/`) — platform-specific wrappers

```
┌─────────┐  ┌──────────┐  ┌────────┐
│  Swift   │  │  Kotlin  │  │   JS   │
│   SDK    │  │   SDK    │  │  SDK   │
└────┬─────┘  └────┬─────┘  └───┬────┘
     │             │             │
     │    ┌────────┴────────┐    │
     └───►│  C Dispatcher   │◄───┘ (native via FFI)
          │  (vtable router)│
          └───────┬─────────┘     ┌──────────────┐
                  │               │  JS Adapter   │◄── (browser via WASM)
          ┌───────┴───────┐       └──────┬────────┘
          │               │              │
     ┌────┴────┐   ┌──────┴──────┐  ┌───┴──────────┐
     │ProveKit │   │Barretenberg │  │ Vendor WASM   │
     │(Rust)   │   │(Rust)       │  │ (@aztec/bb.js)│
     └─────────┘   └─────────────┘  └───────────────┘
```

## Core

### C Dispatcher (`core/dispatcher/`)

The dispatcher routes `verity_*()` calls to the correct backend via a vtable (function pointer table). Each backend registers its vtable at library load time using `__attribute__((constructor))`.

Key files:
- `verity_dispatch.c` — vtable router, handle wrapping/unwrapping
- `verity_backend.h` — vtable interface definition (16 function pointers)
- `backends/pk_backend.c` — ProveKit vtable registration
- `backends/bb_backend.c` — Barretenberg vtable registration

### Public C API (`core/include/`)

- `verity_ffi.h` — stable public API (types, error codes, function declarations)
- `verity_ffi_raw.h` — raw backend symbols (internal, used by dispatcher)

### Rust Backends (`core/backends/`)

Each backend is a Rust crate that compiles to a static library (`staticlib`). The crate exports `extern "C"` functions matching the vtable contract.

Each backend has a `backend.toml` manifest declaring which targets it supports (ios, android, node, wasm).

## SDKs

### Swift (`sdks/swift/`)

Uses Swift Package Manager. The `VerityDispatch` target compiles the C dispatcher, linking against the pre-built `VerityFFI` xcframework. The `Verity` target is pure Swift calling `verity_*()` functions.

### Kotlin (`sdks/kotlin/`)

Android library using Gradle. JNI bridge (`verity_jni.c`) converts between Kotlin types and the C API. Pre-built `.so` files are loaded at runtime via `System.loadLibrary()`.

### JS (`sdks/js/`)

Dual-target npm package:
- **Node.js**: N-API native addon wrapping the C dispatcher (like JNI but for Node)
- **Browser**: WASM bindings or vendor JS adapters per backend

The `BackendBinding` interface in TypeScript mirrors the C vtable contract.

## Adding a Backend

See [Adding a Backend](adding-a-backend.md).

## Adding an SDK

See [Adding an SDK](adding-an-sdk.md).
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture documentation"
```

---

### Task 28: Write backend and SDK contribution guides

**Files:**
- Create: `docs/adding-a-backend.md`
- Create: `docs/adding-an-sdk.md`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Write adding-a-backend.md**

Write `docs/adding-a-backend.md`:
```markdown
# Adding a New Backend

The vtable dispatcher means adding a backend requires **zero changes** to existing SDK code.

## Steps

### 1. Create Rust FFI crate

```
core/backends/your-backend/
├── backend.toml     # Capability manifest
├── Cargo.toml       # Crate config
└── src/lib.rs       # FFI implementation
```

Your crate must export these `extern "C"` functions (replace `yb_` with your prefix):

```rust
#[no_mangle] pub extern "C" fn yb_init() -> i32;
#[no_mangle] pub extern "C" fn yb_prepare(circuit_path: *const c_char, out_prover: *mut *mut YBProver, out_verifier: *mut *mut YBVerifier) -> i32;
#[no_mangle] pub extern "C" fn yb_prove_toml(prover: *const YBProver, toml_path: *const c_char, out: *mut YBBuf) -> i32;
#[no_mangle] pub extern "C" fn yb_prove_json(prover: *const YBProver, inputs_json: *const c_char, out: *mut YBBuf) -> i32;
#[no_mangle] pub extern "C" fn yb_verify(verifier: *const YBVerifier, proof_ptr: *const u8, proof_len: usize) -> i32;
// ... plus load, save, serialize, free (see core/include/verity_ffi_raw.h for full list)
```

### 2. Add vtable registration

Create `core/dispatcher/backends/yb_backend.c` — copy from `pk_backend.c` and replace the prefix.

### 3. Update shared headers

Add enum value in `core/include/verity_ffi.h`:
```c
VERITY_BACKEND_YOUR_BACKEND = 2,
```

Add extern declarations in `core/include/verity_ffi_raw.h`.

### 4. Add Backend enum to each SDK

- Swift: add `case yourBackend = 2` to `Backend` enum
- Kotlin: add `YOUR_BACKEND` to `Backend` enum
- JS: add `YourBackend = 2` to `Backend` enum

### 5. Write backend.toml

Declare which targets your backend supports.

### 6. (Optional) JS adapter

If your backend has a vendor WASM build, create `sdks/js/src/backends/your-backend.ts` implementing `BackendBinding`.

## What you DON'T need to change

- C dispatcher logic (vtable handles routing)
- SDK core classes (Verity, ProverScheme, etc.)
- Existing backends or tests
- CI/CD (new crates are picked up automatically)
```

- [ ] **Step 2: Write adding-an-sdk.md**

Write `docs/adding-an-sdk.md`:
```markdown
# Adding a New SDK

To add support for a new platform (e.g., Flutter, React Native, Go, Python):

## Steps

### 1. Create SDK directory

```
sdks/your-platform/
├── [package manifest]    # pubspec.yaml, setup.py, go.mod, etc.
├── src/                  # SDK source
├── tests/                # Tests
└── scripts/
    └── release.sh        # Publish script
```

### 2. Implement the Verity API

Your SDK must expose this interface (adapted to language idioms):

- `Verity(backend)` — constructor/factory
- `prepare(circuit) → PreparedScheme` — compile circuit
- `prove(prover, inputs) → bytes` — generate proof
- `verify(verifier, proof) → bool` — verify proof
- `loadProver(path | bytes) → ProverScheme`
- `loadVerifier(path | bytes) → VerifierScheme`
- Scheme: `save(path)`, `serialize() → bytes`, `dispose()`

### 3. Create FFI bridge

Write a bridge layer that calls the C `verity_*()` functions. Examples:
- Swift: direct C interop via SPM
- Kotlin: JNI (`verity_jni.c`)
- JS/Node: N-API (`verity_napi.c`)
- Python: ctypes or cffi
- Go: cgo
- Flutter: dart:ffi

### 4. Add build script

Add a build script to `core/build/` for your platform's target triple.

### 5. Add CI workflow

Create `.github/workflows/sdk-your-platform.yml`.

### 6. Add Makefile targets

Add `test-your-platform` and `release-your-platform` to the root Makefile.

### 7. Update docs

- Add install instructions to README.md
- Add examples to `examples/your-platform/`
```

- [ ] **Step 3: Write CONTRIBUTING.md**

Write `CONTRIBUTING.md`:
```markdown
# Contributing

## Adding a New Backend

See [docs/adding-a-backend.md](docs/adding-a-backend.md). The vtable dispatcher means zero changes to existing SDK code.

## Adding a New SDK

See [docs/adding-an-sdk.md](docs/adding-an-sdk.md).

## Development Setup

See [docs/building.md](docs/building.md) for prerequisites and build instructions.

## Testing

```bash
# All platforms
make test-all

# Individual
make test-swift
make test-kotlin
make test-js
```

## Releasing

All SDKs share a single version from the `VERSION` file.

```bash
# Bump version
echo "0.3.0" > VERSION

# Tag and push — CI handles publishing
git add VERSION
git commit -m "chore: bump version to 0.3.0"
git tag v0.3.0
git push origin main --tags
```

## Code Style

- Swift: follow existing patterns, no SwiftLint config yet
- Kotlin: follow existing patterns
- TypeScript: strict mode, ESM
- C: match existing dispatcher style
- Rust: `cargo fmt` + `cargo clippy`
```

- [ ] **Step 4: Commit**

```bash
git add docs/adding-a-backend.md docs/adding-an-sdk.md CONTRIBUTING.md
git commit -m "docs: add backend/SDK contribution guides and update CONTRIBUTING"
```

---

### Task 29: Update remaining docs

**Files:**
- Modify: `docs/building.md`
- Modify: `docs/release.md`

- [ ] **Step 1: Write updated building.md**

Write `docs/building.md`:
```markdown
# Building & Testing

## Prerequisites

- **Rust**: nightly toolchain (`rustup install nightly`)
- **Xcode**: 16+ (for iOS builds)
- **Android NDK**: via Android Studio or standalone
- **Node.js**: 20+ (for JS SDK)
- **wasm-pack**: `cargo install wasm-pack` (for WASM builds)

## Building Core

```bash
# iOS (requires macOS + Xcode)
make core-ios PROVEKIT_PATH=../provekit

# Android
make core-android

# WASM
make core-wasm

# Host native (for testing)
make core-native
```

## Testing

```bash
# Swift SDK
make test-swift

# Kotlin SDK
make test-kotlin

# JS SDK
cd sdks/js && npm install && npm test

# All
make test-all
```

## Project Structure

```
core/               # Shared C + Rust code
├── dispatcher/     # C vtable router
├── include/        # Public C headers
├── backends/       # Rust FFI crates
└── build/          # Per-target build scripts

sdks/
├── swift/          # iOS SDK
├── kotlin/         # Android SDK
└── js/             # JS SDK (Node + browser)
```
```

- [ ] **Step 2: Write updated release.md**

Write `docs/release.md`:
```markdown
# Releasing

## Version

All SDKs share a single version from the root `VERSION` file.

## Process

1. Update `VERSION`:
   ```bash
   echo "0.3.0" > VERSION
   ```

2. Update `sdks/js/package.json` version field to match.

3. Commit and tag:
   ```bash
   git add VERSION sdks/js/package.json
   git commit -m "chore: bump version to 0.3.0"
   git tag v0.3.0
   git push origin main --tags
   ```

4. CI automatically:
   - Builds core for all targets
   - Runs all SDK tests
   - Publishes Swift SDK (GitHub release with XCFramework)
   - Publishes Kotlin SDK (Maven Central)
   - Publishes JS SDK (npm)

## Manual Release

If CI is not available:

```bash
# Swift
make release-swift

# Kotlin
make release-kotlin

# JS
make release-js
```
```

- [ ] **Step 3: Commit**

```bash
git add docs/building.md docs/release.md
git commit -m "docs: update building and release guides for monorepo"
```

---

### Task 30: Create Swift SDK release script

**Files:**
- Modify: `sdks/swift/scripts/release.sh`
- Modify: `sdks/swift/scripts/build-xcframework.sh`

- [ ] **Step 1: Update release.sh paths**

Write `sdks/swift/scripts/release.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SDK_DIR/../.." && pwd)"
OUTPUT_DIR="$REPO_DIR/output"
XCFW="$OUTPUT_DIR/Verity.xcframework"
ZIP="$OUTPUT_DIR/Verity.xcframework.zip"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(cat "$REPO_DIR/VERSION")
    VERSION="v$VERSION"
fi

if [ ! -d "$XCFW" ]; then
    echo "ERROR: xcframework not found at $XCFW"
    echo "Run 'make core-ios' first."
    exit 1
fi

echo "=== Releasing $VERSION ==="

cd "$OUTPUT_DIR"
rm -f Verity.xcframework.zip
zip -r Verity.xcframework.zip Verity.xcframework

CHECKSUM=$(swift package compute-checksum "$ZIP")
echo "Checksum: $CHECKSUM"

echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" "$ZIP" \
    --title "$VERSION" \
    --notes "Pre-built Verity xcframework with all backends"

REPO_URL=$(cd "$REPO_DIR" && gh repo view --json url -q .url 2>/dev/null || echo "https://github.com/atheonxyz/verity")
DOWNLOAD_URL="$REPO_URL/releases/download/$VERSION/Verity.xcframework.zip"

echo ""
echo "=== Done! ==="
echo ""
echo "Update sdks/swift/Package.swift with:"
echo ""
echo "  .binaryTarget("
echo "      name: \"VerityFFI\","
echo "      url: \"$DOWNLOAD_URL\","
echo "      checksum: \"$CHECKSUM\""
echo "  )"

rm -f "$ZIP"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x sdks/swift/scripts/release.sh
chmod +x sdks/swift/scripts/build-xcframework.sh
```

- [ ] **Step 3: Commit**

```bash
git add sdks/swift/scripts/
git commit -m "feat: update Swift release script for monorepo paths"
```

---

### Task 31: Final verification and cleanup

- [ ] **Step 1: Verify directory structure**

```bash
find . -type f -not -path './.git/*' -not -path './.omc/*' -not -path './docs/superpowers/*' | sort
```

Verify all files are in the expected locations per the spec.

- [ ] **Step 2: Verify no old directories remain**

```bash
# These should NOT exist:
ls Sources/ 2>&1 || echo "OK: Sources/ removed"
ls Tests/ 2>&1 || echo "OK: Tests/ removed"
ls include/ 2>&1 || echo "OK: include/ removed"
ls verity-kotlin/ 2>&1 || echo "OK: verity-kotlin/ removed"
ls zkffi/ 2>&1 || echo "OK: zkffi/ removed"
ls Examples/ 2>&1 || echo "OK: Examples/ removed"
ls noir-examples/ 2>&1 || echo "OK: noir-examples/ removed"
ls scripts/ 2>&1 || echo "OK: scripts/ removed"
ls Package.swift 2>&1 || echo "OK: old Package.swift removed"
```

Expected: all "OK" messages

- [ ] **Step 3: Verify Rust workspace**

```bash
cd core && cargo metadata --no-deps --format-version 1 2>&1 | head -3 && cd ..
```

Expected: valid JSON with barretenberg-ffi member

- [ ] **Step 4: Verify TypeScript compiles**

```bash
cd sdks/js && npm install && npx tsc --noEmit 2>&1 && cd ../..
```

Expected: no type errors

- [ ] **Step 5: Run JS tests**

```bash
cd sdks/js && npx vitest run 2>&1 && cd ../..
```

Expected: all tests pass

- [ ] **Step 6: Verify Swift package parses**

```bash
cd sdks/swift && swift package dump-package 2>&1 | head -5 && cd ../..
```

Expected: valid JSON output

- [ ] **Step 7: Final commit (if any unstaged changes)**

```bash
git status
# If clean, skip. If changes, stage and commit:
# git add -A
# git commit -m "chore: final monorepo cleanup"
```
