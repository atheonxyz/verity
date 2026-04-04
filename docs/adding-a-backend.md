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
#[no_mangle] pub extern "C" fn yb_load_prover(...) -> i32;
#[no_mangle] pub extern "C" fn yb_load_verifier(...) -> i32;
#[no_mangle] pub extern "C" fn yb_prove_toml(...) -> i32;
#[no_mangle] pub extern "C" fn yb_prove_json(...) -> i32;
#[no_mangle] pub extern "C" fn yb_verify(...) -> i32;
// ... plus load_bytes, save, serialize, free (see core/include/verity_ffi_raw.h)
```

> **Note:** `prepare` (circuit compilation) is not part of the SDK vtable.
> Backends may optionally implement `yb_prepare()` for use by the offline CLI tool,
> but it is not registered in the vtable or called by the SDK.

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
