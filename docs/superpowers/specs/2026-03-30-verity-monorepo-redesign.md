# Verity SDK Monorepo Redesign

**Date:** 2026-03-30
**Status:** Approved
**Author:** Design collaboration

## Overview

Redesign the Verity ZK proof SDK from an iOS-first repo with Kotlin bolted on into a modular monorepo that supports Swift, Kotlin, and TypeScript/JavaScript — with a clear path for future platforms (Flutter, React Native, Go, Python).

## Goals

- Single `core/` directory owns all shared C and Rust code
- Each platform SDK is self-contained under `sdks/{platform}/`
- Backends declare capabilities per target via manifests
- Full CI/CD: build, test, and publish each SDK independently
- Identical API surface across all platforms, adapted to language idioms
- Single semver version across all SDKs

## Non-Goals

- Flutter, React Native, Go, Python SDKs (future — structure accommodates them)
- Async/await APIs for Swift/Kotlin (future enhancement)
- New ZK backends (structure supports them, but none added in this redesign)

---

## Repository Structure

```
verity/
├── core/
│   ├── Cargo.toml                    # Rust workspace root
│   ├── dispatcher/
│   │   ├── verity_dispatch.c         # Vtable router
│   │   ├── verity_backend.h          # Vtable interface
│   │   ├── backends/
│   │   │   ├── pk_backend.c          # ProveKit registration
│   │   │   └── bb_backend.c          # Barretenberg registration
│   │   └── CMakeLists.txt            # Build dispatcher as static lib
│   ├── include/
│   │   ├── verity_ffi.h              # Public C API (stable, versioned)
│   │   └── verity_ffi_raw.h          # Raw backend symbols (internal)
│   ├── backends/
│   │   └── barretenberg/
│   │       ├── backend.toml          # Capability manifest
│   │       ├── Cargo.toml
│   │       └── src/lib.rs
│   └── build/
│       ├── build-ios.sh
│       ├── build-android.sh
│       ├── build-wasm.sh
│       └── build-native.sh
│
├── sdks/
│   ├── swift/
│   │   ├── Package.swift
│   │   ├── Sources/Verity/
│   │   ├── Tests/VerityTests/
│   │   └── scripts/
│   │       ├── build-xcframework.sh
│   │       └── release.sh
│   │
│   ├── kotlin/
│   │   ├── build.gradle.kts
│   │   ├── src/main/kotlin/com/atheon/verity/
│   │   ├── src/main/jni/
│   │   ├── src/androidTest/
│   │   └── scripts/
│   │       └── release.sh
│   │
│   └── js/
│       ├── package.json
│       ├── tsconfig.json
│       ├── src/
│       │   ├── index.ts              # Auto-detects runtime
│       │   ├── verity.ts             # Core Verity class
│       │   ├── node.ts               # Node.js N-API binding
│       │   ├── browser.ts            # Browser WASM binding
│       │   ├── types.ts              # Shared types
│       │   ├── errors.ts             # Error mappings
│       │   └── backends/             # Per-backend JS adapters
│       ├── native/
│       │   ├── binding.gyp
│       │   └── verity_napi.c         # N-API bridge
│       ├── wasm/
│       │   └── verity_wasm.rs        # wasm-bindgen wrapper
│       ├── tests/
│       └── scripts/
│           └── release.sh
│
├── examples/
│   ├── ios/
│   │   ├── BasicProof/
│   │   └── Showcase/
│   ├── android/
│   │   ├── BasicProof/
│   │   └── Showcase/
│   └── js/
│       ├── node-example/
│       └── browser-example/
│
├── circuits/
│   ├── basic/
│   │   ├── Nargo.toml
│   │   ├── src/main.nr
│   │   └── target/basic.json
│   └── fixtures/
│       ├── circuit.json
│       ├── Prover.toml
│       ├── provekit/
│       └── barretenberg/
│
├── .github/
│   └── workflows/
│       ├── core-build.yml
│       ├── sdk-swift.yml
│       ├── sdk-kotlin.yml
│       ├── sdk-js.yml
│       └── circuits.yml
│
├── docs/
│   ├── architecture.md
│   ├── adding-a-backend.md
│   ├── adding-an-sdk.md
│   ├── building.md
│   ├── roadmap.md
│   └── release.md
│
├── Makefile
├── VERSION
├── CONTRIBUTING.md
├── README.md
├── LICENSE
└── .gitignore
```

---

## Core Build System

### Target matrix

| Target | Toolchain | Output | Consumer |
|--------|-----------|--------|----------|
| `aarch64-apple-ios` + sim | Rust + Xcode | `.a` → XCFramework | Swift SDK |
| `aarch64-linux-android` + x86_64 | Rust + Android NDK | `.so` | Kotlin SDK |
| `wasm32-unknown-unknown` | Rust + wasm-pack | `.wasm` + JS glue | JS SDK (browser) |
| Host native (macOS/Linux) | Rust + cc | `.node` (N-API) | JS SDK (Node) |
| Host native | Rust + cc | `.a` / `.dylib` | Testing |

### Makefile targets

```makefile
core-ios          # builds XCFramework
core-android      # builds .so for arm64-v8a + x86_64
core-wasm         # builds .wasm via wasm-pack
core-native       # builds for host (testing + Node addon)
core-all          # all of the above
test-swift        # builds core-ios, runs Swift tests
test-kotlin       # builds core-android, runs instrumented tests
test-js           # builds core-wasm + core-native, runs JS tests
test-all          # all tests
release-swift     # build + package + publish SPM
release-kotlin    # build + package + publish Maven Central
release-js        # build + package + publish npm
```

### CMake for the C dispatcher

```cmake
# core/dispatcher/CMakeLists.txt
add_library(verity_dispatch STATIC
    verity_dispatch.c
    backends/pk_backend.c
    backends/bb_backend.c
)
target_include_directories(verity_dispatch PUBLIC ../include)
```

---

## Backend Plugin System

### Capability manifest

Each backend declares what it supports per target:

```toml
# core/backends/barretenberg/backend.toml
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

### Three integration patterns

**Pattern 1: Rust FFI crate** — Backend implements vtable functions as `extern "C"` in Rust. Compiles to `.a` for each native target. This is the existing pattern.

**Pattern 2: Vendor WASM** — Backend ships its own WASM build (e.g., `bb.js`). JS SDK wraps it behind the Verity API via adapter code.

**Pattern 3: Rust-to-WASM** — Same Rust FFI crate compiled with `wasm32-unknown-unknown`. Works when deps are WASM-compatible.

### Adding a new backend

1. Create `core/backends/{name}/` with `backend.toml`, `Cargo.toml`, `src/lib.rs`
2. Add `core/dispatcher/backends/{name}_backend.c` with vtable registration
3. Add enum value to `core/include/verity_ffi.h`
4. Add `Backend` enum case in each SDK
5. Optionally add JS adapter in `sdks/js/src/backends/`

No changes needed to dispatcher logic, SDK core classes, or CI.

---

## SDK API Design

### Unified contract

```
init(backend) → prepare(circuit) → prove(prover, inputs) → proof bytes
                                  → verify(verifier, proof) → bool
```

### Swift (unchanged)

```swift
let verity = Verity(backend: .proveKit)
let scheme = try verity.prepare(circuit: circuitJSON)
let proof = try verity.prove(with: scheme.prover, inputs: ["a": 1, "b": 2])
let valid = try verity.verify(with: scheme.verifier, proof: proof)
```

### Kotlin (repackaged to com.atheon.verity)

```kotlin
val verity = Verity(Backend.PROVEKIT)
val scheme = verity.prepare(circuitJSON)
val proof = verity.prove(scheme.prover, mapOf("a" to 1, "b" to 2))
val valid = verity.verify(scheme.verifier, proof)
```

### TypeScript (new, async)

```typescript
import { Verity, Backend } from 'verity';

const verity = await Verity.create(Backend.Barretenberg);
const scheme = await verity.prepare(circuitJSON);
const proof = await verity.prove(scheme.prover, { a: 1, b: 2 });
const valid = await verity.verify(scheme.verifier, proof);
```

Key JS differences:
- `Verity.create()` factory (async WASM init)
- All operations async/await
- `Uint8Array` for proof bytes
- `dispose()` for resource cleanup
- Auto-detects Node vs browser via package.json `exports` field

### Error handling

All platforms use the same error cases:

| Error | Swift | Kotlin | TypeScript |
|-------|-------|--------|------------|
| Not initialized | `VerityError.notInitialized` | `VerityException.NotInitialized` | `VerityError('NOT_INITIALIZED')` |
| Invalid input | `.invalidInput(detail)` | `.InvalidInput(detail)` | `VerityError('INVALID_INPUT', detail)` |
| Proof failed | `.proofFailed(detail)` | `.ProofFailed(detail)` | `VerityError('PROOF_FAILED', detail)` |
| Backend unavailable | `.unknownBackend` | `.UnknownBackend` | `VerityError('BACKEND_UNAVAILABLE')` |

---

## CI/CD Pipelines

### `core-build.yml`

Builds core for all targets. Matrix: iOS (macos-14), Android arm64+x86_64 (ubuntu), WASM (ubuntu), Native macOS+Linux. Uploads artifacts. Caches Rust target dirs by triple + Cargo.lock hash.

### `sdk-swift.yml`

Triggers on `sdks/swift/**` or `core/**`. Calls core-build, packages XCFramework, runs xcodebuild tests. On release tag: zips XCFramework, creates GitHub release, updates Package.swift checksum.

### `sdk-kotlin.yml`

Triggers on `sdks/kotlin/**` or `core/**`. Calls core-build, copies .so into jniLibs, runs `./gradlew connectedAndroidTest`. On release tag: publishes to Maven Central via Sonatype, GPG signed.

### `sdk-js.yml`

Triggers on `sdks/js/**` or `core/**`. Calls core-build, builds N-API addon (prebuildify), builds browser bundle (WASM). Tests: vitest (Node) + vitest+playwright (browser). On release tag: `npm publish @atheon/verity`.

### Release strategy

- Single semver from root `VERSION` file
- Git tag triggers all three publish pipelines
- `com.atheon:verity:X.Y.Z` (Maven), `@atheon/verity@X.Y.Z` (npm), GitHub release (SPM)

---

## Migration Plan

### File moves

| Current | New |
|---------|-----|
| `Sources/Verity/` | `sdks/swift/Sources/Verity/` |
| `Sources/VerityDispatch/verity_dispatch.c` | `core/dispatcher/verity_dispatch.c` |
| `Sources/VerityDispatch/verity_backend.h` | `core/dispatcher/verity_backend.h` |
| `Sources/VerityDispatch/pk_backend.c` | `core/dispatcher/backends/pk_backend.c` |
| `Sources/VerityDispatch/bb_backend.c` | `core/dispatcher/backends/bb_backend.c` |
| `Sources/VerityDispatch/include/verity_ffi.h` | `core/include/verity_ffi.h` |
| `include/verity_ffi_raw.h` | `core/include/verity_ffi_raw.h` |
| `Tests/VerityTests/` | `sdks/swift/Tests/VerityTests/` |
| `verity-kotlin/src/` | `sdks/kotlin/src/` |
| `verity-kotlin/build.gradle.kts` | `sdks/kotlin/build.gradle.kts` |
| `verity-kotlin/Examples/` | `examples/android/` |
| `zkffi/` | `core/backends/` |
| `Examples/` | `examples/ios/` |
| `noir-examples/` | `circuits/` |
| `scripts/build-xcframework.sh` | `sdks/swift/scripts/build-xcframework.sh` |
| `scripts/release.sh` | `sdks/swift/scripts/release.sh` |

### What gets rewritten vs moved

- **Move only:** Swift SDK source, C dispatcher, Rust backend code, tests
- **Move + repackage:** Kotlin SDK (`com.aspect.verity` → `com.atheon.verity`)
- **Rewrite:** `Package.swift`, `build.gradle.kts`, build scripts, README, CONTRIBUTING
- **New:** JS SDK, CI workflows, Makefile, VERSION, architecture docs, backend manifests, CMakeLists.txt

### Migration order

1. Restructure directories (move files, update paths)
2. Get Swift + Kotlin building and tests passing in new locations
3. Build the JS SDK
4. Wire up CI/CD
5. Update all documentation
