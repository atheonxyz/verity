# Verity SDK

Zero-knowledge proof SDK for iOS, Android, and JavaScript. Supports multiple proving backends with a single, unified API.

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

let verity = try Verity(backend: .provekit)
let scheme = try verity.prepare(circuit: "circuit.json")
let proof  = try verity.prove(with: scheme.prover, input: "Prover.toml")
let valid  = try verity.verify(with: scheme.verifier, proof: proof)
```

### Kotlin

```kotlin
import com.atheon.verity.*

val verity = Verity(Backend.PROVEKIT)
val scheme = verity.prepare("circuit.json")
val proof  = verity.prove(scheme.prover, "Prover.toml")
val valid  = verity.verify(scheme.verifier, proof)
scheme.close()
```

### TypeScript

```typescript
import { Verity, Backend } from '@atheon/verity';

const verity = await Verity.create(Backend.Barretenberg);
const scheme = await verity.prepare(circuitJSON);
const proof  = await verity.prove(scheme.prover, { a: 1, b: 2 });
const valid  = await verity.verify(scheme.verifier, proof);
scheme.dispose();
```

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
│   ├── swift/      # iOS SDK (Swift Package Manager)
│   ├── kotlin/     # Android SDK (Gradle / Maven)
│   └── js/         # JS SDK (npm, Node + browser)
├── examples/       # Platform-specific demo apps
├── circuits/       # Noir test circuits and fixtures
└── docs/           # Architecture, guides, roadmap
```

## Docs

- [Architecture](docs/architecture.md) — how core + SDKs fit together
- [Adding a Backend](docs/adding-a-backend.md) — contribute a new ZK backend
- [Adding an SDK](docs/adding-an-sdk.md) — add support for a new platform
- [Building & Testing](docs/building.md) — developer setup
- [Roadmap](docs/roadmap.md) — what's next

## License

MIT
