# Verity SDK

[![CI](https://github.com/atheonxyz/verity/actions/workflows/ci.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/ci.yml)
[![Security](https://github.com/atheonxyz/verity/actions/workflows/security.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/security.yml)
[![Nightly](https://github.com/atheonxyz/verity/actions/workflows/nightly.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/nightly.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Zero-knowledge proof SDK for **iOS**, **Android**, and **JavaScript**. One API, multiple proving backends, every platform.

## Features

- **Unified API** -- `prepare`, `prove`, `verify` across all platforms
- **Pluggable backends** -- switch between ProveKit and Barretenberg with one line
- **Offline key management** -- save/load/serialize prover and verifier schemes
- **Thread-safe** -- safe to use from multiple threads and async contexts
- **Tiny binaries** -- optimized builds with LTO, symbol stripping, and size-opt profiles
- **Type-safe errors** -- structured error types with actionable fix suggestions

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

let verity  = try Verity(backend: .provekit)
let circuit = try Circuit.load(from: "circuit.json")
let witness = try Witness.load(from: "Prover.toml")
let scheme  = try verity.prepare(circuit: circuit)
let proof   = try scheme.prover.prove(witness: witness)
let valid   = try scheme.verifier.verify(proof: proof)

print(proof.hexPreview())  // "a1b2c3d4..."
```

### Kotlin

```kotlin
import com.atheon.verity.*

val verity  = Verity(Backend.PROVEKIT)
val circuit = Circuit.load("circuit.json")
val witness = Witness.load("Prover.toml")
verity.prepare(circuit).use { scheme ->
    val proof = scheme.prover.prove(witness)
    val valid = scheme.verifier.verify(proof)
    println(proof.hexPreview())  // "a1b2c3d4..."
}
```

### TypeScript

```typescript
import { Verity, Backend } from '@atheon/verity';

const verity = await Verity.create(Backend.Barretenberg);
const scheme = await verity.prepare(circuitJSON);
const proof  = await scheme.prover.prove({ a: 1, b: 2 });
const valid  = await scheme.verifier.verify(proof);
scheme.dispose();
```

## API Overview

| Method | Description |
|--------|-------------|
| `Verity(backend:)` | Create a factory with the specified backend |
| `verity.prepare(circuit:)` | Compile a circuit into prover + verifier schemes |
| `prover.prove(witness:)` | Generate a proof from witness values |
| `verifier.verify(proof:)` | Verify a proof -- returns `true` / `false` |
| `Circuit.load(from:)` | Load a compiled circuit from a file |
| `Witness.load(from:)` | Load witness values from a TOML file |
| `Witness(["x": "5"])` | Create witness from a dictionary |
| `verity.loadProver(from:)` | Load a saved prover scheme from file or bytes |
| `verity.loadVerifier(from:)` | Load a saved verifier scheme from file or bytes |
| `scheme.save(to:)` | Save a scheme to disk |
| `scheme.serialize()` | Serialize a scheme to bytes |

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
│   ├── swift/      # iOS / macOS SDK (Swift Package Manager)
│   ├── kotlin/     # Android SDK (Gradle / Maven)
│   └── js/         # JS SDK (npm, Node + browser)
├── examples/       # Platform-specific demo apps
├── circuits/       # Noir test circuits and fixtures
└── docs/           # Architecture, guides, roadmap
```

## Docs

- [Architecture](docs/architecture.md) -- how core + SDKs fit together
- [Adding a Backend](docs/adding-a-backend.md) -- contribute a new ZK backend
- [Adding an SDK](docs/adding-an-sdk.md) -- add support for a new platform
- [Building & Testing](docs/building.md) -- developer setup
- [Changelog](CHANGELOG.md) -- release history
- [Security](SECURITY.md) -- vulnerability reporting

## License

MIT
