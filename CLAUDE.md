# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Verity is a zero-knowledge proof SDK for iOS, Android, and JavaScript/Node.js. It supports multiple proving backends (ProveKit, Barretenberg) through a single unified API. The repo is a monorepo with shared C/Rust core code and platform-specific SDK wrappers.

## Build Commands

All core builds require ProveKit as a sibling directory (default `../provekit`):

```bash
make core-ios PROVEKIT_PATH=../provekit    # iOS (aarch64 device + simulator)
make core-android PROVEKIT_PATH=../provekit # Android NDK
make core-wasm                              # WebAssembly
make core-native                            # Host platform (for testing)
make core-all PROVEKIT_PATH=../provekit     # All targets
```

## Testing

```bash
make test-fixtures             # generate .pkp/.pkv fixtures from circuit.json (requires core-native)
make test-swift                # xcodebuild test on iPhone 16 simulator
make test-kotlin               # ./gradlew connectedAndroidTest
make test-js                   # vitest run (cd sdks/js && npm test)
make test-all                  # All SDKs

# JS SDK individually
cd sdks/js && npm install && npm test
cd sdks/js && npm run test:watch   # Watch mode
```

## Linting

```bash
cd core && cargo fmt && cargo clippy   # Rust
cd sdks/js && npm run lint             # TypeScript (tsc --noEmit)
```

## Architecture

Three-layer stack:

```
Platform SDKs (Swift, Kotlin, TypeScript)
        ↓ FFI
C Dispatcher (vtable router)
        ↓ function pointers
Rust FFI Backends (ProveKit, Barretenberg)
```

### C Dispatcher (`core/dispatcher/`)

The dispatcher uses a **vtable (function pointer table)** pattern to route `verity_*()` calls to the correct backend. Each backend registers its 16-function vtable at library load time via `__attribute__((constructor))`.

- `verity_dispatch.c` — core router, handle wrapping/unwrapping, all `verity_*()` implementations
- `verity_backend.h` — `VerityVtable` struct definition (16 function pointers)
- `backends/pk_backend.c` / `bb_backend.c` — backend registration stubs

### Public C API (`core/include/`)

- `verity_ffi.h` — stable public API (types, error codes, function declarations)
- `verity_ffi_raw.h` — raw backend symbols (`pk_*`, `bb_*`), internal use by dispatcher

### Rust Backends (`core/backends/`)

Each backend is a Rust crate compiled to `staticlib`, exporting `extern "C"` functions matching the vtable contract. Each has a `backend.toml` declaring supported targets (ios, android, node, wasm).

### SDK Bindings

- **Swift** (`sdks/swift/`): SPM package. `VerityDispatch` target compiles C dispatcher, links pre-built `VerityFFI.xcframework`. `Verity` target is pure Swift.
- **Kotlin** (`sdks/kotlin/`): Gradle Android library. JNI bridge (`verity_jni.c`) converts between Kotlin/C. Pre-built `.so` files loaded via `System.loadLibrary()`.
- **JS** (`sdks/js/`): Dual-target npm package. Node.js uses N-API native addon; browser uses WASM/vendor JS adapters. Built with tsup, tested with vitest.

## Key Design Decisions

- **Adding a backend requires zero SDK changes**: implement 16 FFI functions, create a registration stub, add an enum value. The vtable dispatcher handles routing.
- **Single `VERSION` file** at repo root controls all SDK versions. JS SDK `package.json` version must be updated separately.
- **Rust release profile** optimizes aggressively for size: `lto = "fat"`, `codegen-units = 1`, `opt-level = "z"`, `strip = "symbols"`.
- **Symmetric buffer contract**: all backends use identical `{ ptr, len, cap }` layout for serialization interop.

## Boundary Contract (MUST respect on every change)

Three strict boundary layers. Changes must never break the layer above or below.

### Layer 3: Platform SDKs → Unified C API

SDKs (Swift/Kotlin/JS) call ONLY `verity_*()` functions from `verity_ffi.h`. Zero backend-specific code in any SDK. The `VerityBackend` enum is passed to load functions (`verity_load_*`). Operation functions (`verity_prove_*`, `verity_verify`, `verity_save_*`, `verity_free_*`) read the backend from the opaque handle — no enum needed.

### Layer 2: Vtable Standard — 16 functions every backend must implement

Defined in `core/dispatcher/verity_backend.h`. All types are generic (`void *` handles, `RawBuf` byte buffers, `const char *` strings). No proof-system-specific concepts.

Note: `prepare` (circuit compilation) is NOT part of the SDK vtable. Compilation is done offline via a CLI tool; the SDK only loads pre-compiled schemes.

```
 #  Category     Function                                              Signature (vtable)
 1  Lifecycle    init                                                  () → int
 2  Load         load_prover                                           (path, **out) → int
 3  Load         load_verifier                                         (path, **out) → int
 4  Load         load_prover_bytes                                     (ptr, len, **out) → int
 5  Load         load_verifier_bytes                                   (ptr, len, **out) → int
 6  Save         save_prover                                           (prover, path) → int
 7  Save         save_verifier                                         (verifier, path) → int
 8  Serialize    serialize_prover                                      (prover, *out_buf) → int
 9  Serialize    serialize_verifier                                    (verifier, *out_buf) → int
10  Prove        prove_toml                                            (prover, toml_path, *out_buf) → int
11  Prove        prove_json                                            (prover, json_string, *out_buf) → int
12  Verify       verify                                                (verifier, proof_ptr, proof_len) → int
13  Diagnostics  last_error_message                                    (*out_buf) → int
14  Cleanup      free_prover                                           (prover) → void
15  Cleanup      free_verifier                                         (verifier) → void
16  Cleanup      free_buf                                              (buf) → void
```

Error codes (shared across all layers): 0=Success, 1=InvalidInput, 2=SchemeReadError, 3=WitnessReadError, 4=ProofError, 5=SerializationError, 6=Utf8Error, 7=FileWriteError, 8=Reserved, 9=UnknownBackend, 10=OutOfMemory.

### Layer 1: Backend FFI → ProveKit/Barretenberg

Each backend (`pk_*`, `bb_*`) implements the 16 functions and registers via `__attribute__((constructor))`. The `xx_backend.c` wrapper casts between typed backend pointers and generic `void *`. Key rules:

- `free_buf`: vtable convention is pass-by-value (`RawBuf buf`). If a backend takes a pointer (e.g., ProveKit's `pk_free_buf(PKBuf *)`), the wrapper bridges it with `&local_copy`.
- Buffer layout: `{ uint8_t *ptr, uintptr_t len, uintptr_t cap }` — verified at compile time by `_Static_assert` in each `xx_backend.c`.
- Backend registration validates all 16 vtable slots are non-NULL before accepting.
- Backends may still implement `prepare` internally (e.g., `pk_prepare`, `bb_prepare`) for use by offline CLI tools, but this is NOT part of the SDK vtable.

### Canonical references

- Vtable definition: `core/dispatcher/verity_backend.h`
- ProveKit FFI header: `../provekit/tooling/provekit-ffi/include/provekit_ffi.h`
- Architecture spec: `../provekit/docs/sdk-architecture.md`

### When changing ANY layer, verify:

1. Does the ProveKit FFI C header (`provekit_ffi.h`) match `verity_ffi_raw.h` pk_* declarations?
2. Does `pk_backend.c` wrapper match both the vtable signatures AND the pk_* signatures?
3. Do the platform SDKs only call `verity_*` functions — never `pk_*` or `bb_*` directly?

## Code Style

- Rust: `cargo fmt` + `cargo clippy`
- TypeScript: strict mode, ESM-first
- C: match existing dispatcher style (no formal linter)
- Swift/Kotlin: follow existing patterns

## Release Process

1. Update `VERSION` file and `sdks/js/package.json`
2. Commit, tag (`v0.X.0`), push with tags
3. CI builds all targets and publishes to SPM, Maven Central, npm
