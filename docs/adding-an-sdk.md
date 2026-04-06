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
- `loadProver(path | bytes) → ProverScheme` — load pre-compiled prover
- `loadVerifier(path | bytes) → VerifierScheme` — load pre-compiled verifier
- `prove(prover, inputs) → bytes` — generate proof
- `verify(verifier, proof) → bool` — verify proof
- Scheme: `save(path)`, `serialize() → bytes`, `dispose()`

> **Note:** The SDK does not expose circuit compilation (`prepare`).
> Users obtain pre-compiled prover/verifier schemes via the CLI tool or downloads.

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
