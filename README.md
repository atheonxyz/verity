# Verity

Zero-knowledge proofs for **iOS**, **Android**, and **JavaScript**.
One API. Multiple proving backends. Every platform.

[![CI](https://github.com/atheonxyz/verity/actions/workflows/ci.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/ci.yml)
[![Security](https://github.com/atheonxyz/verity/actions/workflows/security.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/security.yml)
[![Version](https://img.shields.io/github/v/release/atheonxyz/verity)](https://github.com/atheonxyz/verity/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![iOS](https://img.shields.io/badge/iOS_15+-000000?logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android_API_24+-3DDC84?logo=android&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?logo=nodedotjs&logoColor=white)
![Browser](https://img.shields.io/badge/Browser-4285F4?logo=googlechrome&logoColor=white)

- **One API everywhere** — the same `load`, `prove`, `verify` flow across Swift, Kotlin, and TypeScript
- **Pluggable backends** — ProveKit today, with Barretenberg, Circom, Jolt, and more on the roadmap. Swap backends without changing application code.
- **Production-ready** — LTO-optimized binaries, thread-safe initialization, structured error handling with actionable fix suggestions

---

## Install

### Swift (iOS 15+ / macOS 13+)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/atheonxyz/verity", from: "0.3.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Verity", package: "verity")
    ])
]
```

### Kotlin (Android API 24+)

```kotlin
// build.gradle.kts
dependencies {
    implementation("xyz.atheon:verity:0.3.0")
}
```

### JavaScript / TypeScript

```bash
npm install @atheon/verity
```

---

## Quick Start

Circuits are written in [Noir](https://noir-lang.org) and compiled offline. The SDK loads pre-compiled prover and verifier schemes — your application never touches the circuit compiler.

### Swift

```swift
import Verity

let verity   = try Verity(backend: .provekit)
let prover   = try verity.loadProver(from: "scheme.pkp")
let verifier = try verity.loadVerifier(from: "scheme.pkv")

let witness = Witness(values: ["age": "25", "threshold": "18"])
let proof   = try prover.prove(witness: witness)
let valid   = try verifier.verify(proof: proof)
```

### Kotlin

```kotlin
import xyz.atheon.verity.*

val verity   = Verity(Backend.PROVEKIT)
val prover   = verity.loadProver("scheme.pkp")
val verifier = verity.loadVerifier("scheme.pkv")

prover.use { p ->
    verifier.use { v ->
        val witness = Witness.of(mapOf("age" to "25", "threshold" to "18"))
        val proof   = p.prove(witness)
        val valid   = v.verify(proof)
    }
}
```

### TypeScript

```typescript
import { Verity, Backend } from "@atheon/verity";

const verity = await Verity.create(Backend.ProveKit);

// Load pre-compiled schemes (via fetch, fs.readFile, or bundled assets)
const prover   = await verity.loadProver(proverBytes);
const verifier = await verity.loadVerifier(verifierBytes);

const proof = await verity.prove(prover, { age: "25", threshold: "18" });
const valid = await verity.verify(verifier, proof);
```

---

## How It Works

```
┌───────────────────────────────────────────────┐
│             Platform SDKs                     │
│       Swift  ·  Kotlin  ·  TypeScript         │
└───────────────────────┬───────────────────────┘
                        │ FFI
┌───────────────────────▼───────────────────────┐
│         C Dispatcher (vtable router)          │
│   Routes verity_*() calls to the active       │
│   backend via function-pointer table          │
└───────────┬───────────────────┬───────────────┘
            │                   │
┌───────────▼─────────┐ ┌──────▼────────────────┐
│  ProveKit (WHIR)    │ │  Barretenberg [dev]   │
│  Rust staticlib     │ │  Rust staticlib       │
└─────────────────────┘ └───────────────────────┘
```

Your application talks to one unified API. The C dispatcher routes calls to the correct proving backend at runtime through a vtable of 16 function pointers. Each backend is an isolated Rust static library that implements this contract.

Adding a new backend requires zero changes to any SDK. Implement the 16 FFI functions, register a vtable entry, and every platform gets the new backend automatically.

> [!TIP]
> See [Architecture](docs/architecture.md) for the full design, including the vtable contract, buffer layout, and error propagation model.

---

## Backends

| Backend | Status | Trusted Setup | Proof Size |
|---------|--------|---------------|------------|
| **ProveKit** (WHIR) | Production | None (transparent) | Variable (~KBs) |
| **Barretenberg** (UltraHonk) | In Development | Universal (auto) | Several KB |

Switching backends changes one line. The rest of your code stays identical.

> [!NOTE]
> Additional backends — including Circom, Jolt, and more — are on the [roadmap](docs/roadmap.md).

---

## API Overview

| Method | Description |
|--------|-------------|
| `Verity(backend)` | Initialize with a specific proving backend |
| `loadProver(source)` | Load a prover scheme from a file path or raw bytes |
| `loadVerifier(source)` | Load a verifier scheme from a file path or raw bytes |
| `prove(witness)` | Generate a zero-knowledge proof from witness inputs |
| `verify(proof)` | Verify a proof — returns `true` if valid |
| `save(path)` | Persist a scheme to disk |
| `serialize()` | Serialize a scheme to bytes for transport or storage |

---

## Repository Structure

```
verity/
├── core/             # C dispatcher + Rust FFI backends
├── sdks/
│   ├── swift/        # iOS / macOS SDK (Swift Package Manager)
│   ├── kotlin/       # Android SDK (Gradle / Maven Central)
│   └── js/           # JavaScript SDK (npm — Node.js + browser)
├── examples/         # Demo apps (iOS, Android, Node.js, browser)
├── circuits/         # Noir test circuits and fixtures
├── scripts/          # Build and release scripts
├── docs/             # Architecture, guides, roadmap
├── Makefile          # Build targets for all platforms
├── Package.swift     # Root SPM package definition
└── VERSION           # Single source of truth for SDK version
```

---

## Examples

Working demo applications for each platform:

- **iOS** — [examples/ios/VerityDemo](examples/ios/VerityDemo)
- **Android** — [examples/android/VerityDemo](examples/android/VerityDemo)
- **Node.js** — [examples/js/node-example](examples/js/node-example)
- **Browser** — [examples/js/browser-example](examples/js/browser-example)

---

## Documentation

- [Architecture](docs/architecture.md) — how the dispatcher, backends, and SDKs fit together
- [Building & Testing](docs/building.md) — developer setup, build targets, and test commands
- [Adding a Backend](docs/adding-a-backend.md) — contribute a new ZK proving backend
- [Adding an SDK](docs/adding-an-sdk.md) — add support for a new platform
- [Release Process](docs/release.md) — versioning and publishing
- [Roadmap](docs/roadmap.md) — planned backends, async APIs, and new platforms
- [Changelog](CHANGELOG.md) — release history

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and release process.

## Security

Report vulnerabilities to **security@atheon.xyz**. See [SECURITY.md](SECURITY.md) for scope and disclosure policy.

## License

MIT
