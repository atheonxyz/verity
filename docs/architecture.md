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
