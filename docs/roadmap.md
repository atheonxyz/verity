# Roadmap

## Completed (v0.2.0)

- [x] Kotlin Android SDK with JNI bridge
- [x] JavaScript/TypeScript SDK scaffolding (types, errors, async API)
- [x] CI/CD pipelines for core builds and all SDKs
- [x] Thread-safe backend initialization (Swift + Kotlin)
- [x] Release trigger via GitHub Actions on tag push

## In Progress

### Error String Propagation
Propagate actual Rust error strings through FFI instead of just error codes. Currently backends return integer codes; the SDK maps them to generic messages. Passing the original error string would give developers much better debugging context.

### JS SDK Backend Bindings
Complete the N-API (Node.js) and WASM (browser) backend bindings. The TypeScript API layer is done; the native bridge needs implementation.

## Planned

### Async / Await APIs
Proof generation is CPU-heavy and blocks the calling thread. Add async wrappers:
- **Swift**: `async throws` variants of `prepare`, `prove`, `verify`
- **Kotlin**: `suspend` function variants with coroutine support
- **JS**: Already async by design

### Additional Backends
- **Halo2** -- evaluate integration complexity and community interest
- **SP1** -- RISC-V zkVM backend
- **Jolt** -- Lasso-based zkVM

### Nargo Integration
Built-in `nargo compile` and `nargo execute` support so developers don't need the Noir toolchain installed separately.

### Cross-Language Schema Validation
Use protobuf or similar schema for circuit inputs to prevent type mismatches across SDKs. Currently each SDK does its own JSON/TOML serialization.

### Additional SDK Platforms
- Flutter (Dart FFI)
- React Native (JSI bridge)
- Go (cgo)
- Python (ctypes / cffi)
