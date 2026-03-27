# Verity Kotlin SDK

Zero-knowledge proof SDK for Android. Supports multiple proving backends with a single API.

## How it works

```
┌─────────────────────────────────────────────────┐
│              Your Android App                   │
│         Verity(backend: .provekit)              │
└──────────────────┬──────────────────────────────┘
                   │  Kotlin API
┌──────────────────▼──────────────────────────────┐
│              Verity SDK                         │
│   prepare() · prove() · verify()               │
│   ProverScheme · VerifierScheme                 │
└──────────────────┬──────────────────────────────┘
                   │  JNI
┌──────────────────▼──────────────────────────────┐
│           C Dispatch Layer                      │
│   verity_dispatch.c  (vtable routing)           │
│   pk_backend.c  ·  bb_backend.c                 │
└───────┬─────────────────────┬───────────────────┘
        │                     │
┌───────▼───────┐     ┌───────▼───────┐
│  ProveKit FFI │     │ Barretenberg  │
│  (WHIR)       │     │  FFI (UltraHonk)│
│  Rust → .a    │     │  Rust → .a    │
└───────────────┘     └───────────────┘
```

The SDK compiles Noir circuits into prover/verifier schemes, generates proofs on-device, and verifies them — all through a unified Kotlin API. A C dispatch layer routes calls to the selected backend via function-pointer vtables, so adding a new backend requires zero changes to the Kotlin layer.

## Install

Add the library module to your project:

```kotlin
// settings.gradle.kts
include(":verity-kotlin")
project(":verity-kotlin").projectDir = file("path/to/verity-kotlin")

// app/build.gradle.kts
dependencies {
    implementation(project(":verity-kotlin"))
}
```

## Quick Start

```kotlin
import com.aspect.verity.Verity
import com.aspect.verity.Backend

val verity = Verity(Backend.PROVEKIT)  // or Backend.BARRETENBERG

// 1. Prepare — compile circuit into prover + verifier schemes
val scheme = verity.prepare(circuit = "circuit.json")

// 2. Prove
val proof = verity.prove(with = scheme.prover, input = "Prover.toml")

// 3. Verify
val valid = verity.verify(with = scheme.verifier, proof = proof)
```

`proof` is a `ByteArray` — save it, send it, verify it anywhere.

---

## Usage Patterns

### Prove with a map (no TOML file)

```kotlin
val proof = verity.prove(with = scheme.prover, inputs = mapOf(
    "a" to "1",
    "b" to "2",
    "c" to "3",
    "d" to "5"
))
```

### Save schemes to disk (prepare once, reuse forever)

```kotlin
// Prepare is slow (~seconds). Do it once.
val scheme = verity.prepare(circuit = "circuit.json")

// Save for later
scheme.prover.save("/data/cache/prover.pkp")
scheme.verifier.save("/data/cache/verifier.pkv")
```

### Load schemes from file

```kotlin
// Next app launch — skip prepare, load instantly
val prover = verity.loadProver("/data/cache/prover.pkp")
val verifier = verity.loadVerifier("/data/cache/verifier.pkv")

val proof = verity.prove(with = prover, input = "Prover.toml")
val valid = verity.verify(with = verifier, proof = proof)
```

### Load from downloaded bytes (no temp file needed)

```kotlin
// Download .pkp from your server
val pkpData = URL(serverUrl).readBytes()

// Load directly from bytes
val prover = verity.loadProver(data = pkpData)
val proof = verity.prove(with = prover, inputs = mapOf("a" to "1", "b" to "2"))
```

### Serialize schemes to bytes (for network transfer, database, etc.)

```kotlin
// Sender
val proverBytes = scheme.prover.serialize()
val verifierBytes = scheme.verifier.serialize()
// Send over network, store in Room, cache in SharedPreferences...

// Receiver
val prover = verity.loadProver(data = proverBytes)
val verifier = verity.loadVerifier(data = verifierBytes)
```

### Reuse schemes for multiple proofs

```kotlin
val scheme = verity.prepare(circuit = "circuit.json")

val proof1 = verity.prove(with = scheme.prover, inputs = mapOf("a" to "1", "b" to "2", "c" to "3", "d" to "5"))
val proof2 = verity.prove(with = scheme.prover, inputs = mapOf("a" to "2", "b" to "1", "c" to "3", "d" to "5"))

verity.verify(with = scheme.verifier, proof = proof1)  // true
verity.verify(with = scheme.verifier, proof = proof2)  // true
```

### Switch backends (one line change)

```kotlin
// ProveKit — transparent, no trusted setup
val pk = Verity(Backend.PROVEKIT)
val proof = pk.prove(with = scheme.prover, input = "Prover.toml")

// Barretenberg — same API, different backend
val bb = Verity(Backend.BARRETENBERG)
val proof = bb.prove(with = scheme.prover, input = "Prover.toml")
```

---

## Typical App Integration

```kotlin
class ZKProofManager(backend: Backend = Backend.PROVEKIT) {
    private val verity = Verity(backend)
    private var prover: ProverScheme? = null
    private var verifier: VerifierScheme? = null

    /** Call once at app startup. */
    fun loadSchemes(proverPath: String, verifierPath: String) {
        prover = verity.loadProver(proverPath)
        verifier = verity.loadVerifier(verifierPath)
    }

    /** Generate a proof on a background thread. */
    suspend fun prove(inputs: Map<String, Any>): ByteArray =
        withContext(Dispatchers.Default) {
            verity.prove(with = prover!!, inputs = inputs)
        }

    /** Verify a received proof. */
    fun verify(proof: ByteArray): Boolean =
        verity.verify(with = verifier!!, proof = proof)
}
```

---

## Backends

| Backend | Init | Trusted Setup | Proof Size |
|---------|------|---------------|------------|
| ProveKit (WHIR) | `Backend.PROVEKIT` | None (transparent) | Variable (~KBs) |
| Barretenberg (UltraHonk) | `Backend.BARRETENBERG` | Universal (auto-downloaded) | Several KB |

Switching backends changes one line. The rest of your code stays identical.

## API Summary

| Method | What it does |
|--------|-------------|
| `Verity(backend)` | Initialize with a backend |
| `prepare(circuit)` | Compile circuit -> `PreparedScheme` (prover + verifier) |
| `prove(with, input)` | Prove with TOML file -> `ByteArray` |
| `prove(with, inputs)` | Prove with map -> `ByteArray` |
| `verify(with, proof)` | Verify proof -> `Boolean` |
| `loadProver(path)` | Load prover from file -> `ProverScheme` |
| `loadProver(data)` | Load prover from bytes -> `ProverScheme` |
| `loadVerifier(path)` | Load verifier from file -> `VerifierScheme` |
| `loadVerifier(data)` | Load verifier from bytes -> `VerifierScheme` |
| `prover.save(path)` | Save prover to file |
| `prover.serialize()` | Serialize prover to bytes -> `ByteArray` |
| `verifier.save(path)` | Save verifier to file |
| `verifier.serialize()` | Serialize verifier to bytes -> `ByteArray` |

---

## Building from Source

### Prerequisites

- Android NDK (set `ANDROID_NDK_HOME` or let the script auto-detect)
- Rust toolchain with Android targets
- [ProveKit](https://github.com/aspect-build/provekit) repo cloned locally

### Build native libraries

```bash
cd verity-kotlin

# Set paths (or let defaults resolve relative to repo)
export PROVEKIT_ROOT=/path/to/provekit        # required
# BB_FFI_ROOT and VERITY_DISPATCH_DIR auto-resolve within the repo

bash scripts/build-android.sh
```

This compiles `libverity_jni.so` for `arm64-v8a` and `x86_64` into `src/main/jniLibs/`.

### Run examples

1. Open `Examples/BasicProof/` or `Examples/Showcase/` in Android Studio
2. Connect a device or start an emulator
3. Run the app

**BasicProof** — demonstrates the prepare -> prove -> verify flow with multiple circuits and backends.

**Showcase** — exercises every SDK capability: scheme loading, TOML/map proving, save/load round-trips, serialization, and backend comparison.

### Run tests

```bash
# Copy test fixtures from the Swift SDK
cp Tests/VerityTests/Fixtures/circuit.json verity-kotlin/src/androidTest/assets/fixtures/
cp Tests/VerityTests/Fixtures/Prover.toml  verity-kotlin/src/androidTest/assets/fixtures/

# Run instrumented tests on a connected device
./gradlew :verity-kotlin:connectedAndroidTest
```

## Examples

See [`Examples/`](Examples/) for Android demo apps with circuits included.

## Docs

- [Testing Guide](TESTING.md) — running tests and fixtures
- [Contributing](../CONTRIBUTING.md) — adding new backends
