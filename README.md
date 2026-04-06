# Verity SDK

[![CI](https://github.com/atheonxyz/verity/actions/workflows/ci.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/ci.yml)
[![Security](https://github.com/atheonxyz/verity/actions/workflows/security.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/security.yml)
[![Nightly](https://github.com/atheonxyz/verity/actions/workflows/nightly.yml/badge.svg)](https://github.com/atheonxyz/verity/actions/workflows/nightly.yml)
Zero-knowledge proof SDK for **iOS**, **Android**, and **JavaScript**. One API, multiple proving backends, every platform.

## Features

- **Unified API** -- `load`, `prove`, `verify` across all platforms
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
    .package(url: "https://github.com/atheonxyz/verity", from: "0.3.0")
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
    implementation("xyz.atheon:verity:0.3.0")
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

let verity   = try Verity(backend: .provekit)
let prover   = try verity.loadProver(from: "prover.pkp")
let verifier = try verity.loadVerifier(from: "verifier.pkv")
let witness  = try Witness.load(from: "Prover.toml")
let proof    = try prover.prove(witness: witness)
let valid    = try verifier.verify(proof: proof)

print(proof.hexPreview())  // "a1b2c3d4..."
```

### Kotlin

```kotlin
import xyz.atheon.verity.*

val verity   = Verity(Backend.PROVEKIT)
val prover   = verity.loadProver("prover.pkp")
val verifier = verity.loadVerifier("verifier.pkv")
val witness  = Witness.load("Prover.toml")
prover.use { p ->
    verifier.use { v ->
        val proof = p.prove(witness)
        val valid = v.verify(proof)
        println(proof.hexPreview())  // "a1b2c3d4..."
    }
}
```

### TypeScript

```typescript
import { Verity, Backend } from '@atheon/verity';

const verity   = await Verity.create(Backend.Barretenberg);
const prover   = await verity.loadProver(proverBytes);
const verifier = await verity.loadVerifier(verifierBytes);
const proof    = await verity.prove(prover, { a: 1, b: 2 });
const valid    = await verity.verify(verifier, proof);
prover.dispose();
verifier.dispose();
```

## API Overview

| Method | Description |
|--------|-------------|
| `Verity(backend:)` | Create a factory with the specified backend |
| `verity.loadProver(from:)` | Load a prover scheme from file or bytes |
| `verity.loadVerifier(from:)` | Load a verifier scheme from file or bytes |
| `prover.prove(witness:)` | Generate a proof from witness values |
| `verifier.verify(proof:)` | Verify a proof -- returns `true` / `false` |
| `Witness.load(from:)` | Load witness values from a TOML file |
| `Witness(["x": "5"])` | Create witness from a dictionary |
| `scheme.save(to:)` | Save a scheme to disk |
| `scheme.serialize()` | Serialize a scheme to bytes |

## Backends

| Backend | Enum | Trusted Setup | Proof Size |
|---------|------|---------------|------------|
| ProveKit (WHIR) | `.provekit` (Swift) / `PROVEKIT` (Kotlin) / `ProveKit` (JS) | None (transparent) | Variable (~KBs) |
| Barretenberg (UltraHonk) | `.barretenberg` (Swift) / `BARRETENBERG` (Kotlin) / `Barretenberg` (JS) | Universal (auto) | Several KB |

Switching backends changes one line. The rest of your code stays identical.

## Repo Structure

```
verity/
├── core/           # Shared C dispatcher + Rust FFI backends
├── sdks/
│   ├── swift/      # iOS / macOS SDK (Swift Package Manager)
│   ├── kotlin/     # Android SDK (Gradle / Maven)
│   └── js/         # JS SDK (npm, Node + browser)
├── tests/          # Fixture generation tools
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
