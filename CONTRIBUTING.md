# Contributing

## Adding a New Backend

See [docs/adding-a-backend.md](docs/adding-a-backend.md). The vtable dispatcher means zero changes to existing SDK code.

## Adding a New SDK

See [docs/adding-an-sdk.md](docs/adding-an-sdk.md).

## Development Setup

See [docs/building.md](docs/building.md) for prerequisites and build instructions.

## Testing

```bash
# All platforms
make test-all

# Individual
make test-swift
make test-kotlin
make test-js
```

## Releasing

All SDKs share a single version from the `VERSION` file.

```bash
# Bump version
echo "0.3.0" > VERSION

# Tag and push — CI handles publishing
git add VERSION
git commit -m "chore: bump version to 0.3.0"
git tag v0.3.0
git push origin main --tags
```

## Code Style

- Swift: follow existing patterns, no SwiftLint config yet
- Kotlin: follow existing patterns
- TypeScript: strict mode, ESM
- C: match existing dispatcher style
- Rust: `cargo fmt` + `cargo clippy`
