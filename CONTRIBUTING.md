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

## Code Style

- Swift: follow existing patterns, no SwiftLint config yet
- Kotlin: follow existing patterns
- TypeScript: strict mode, ESM
- C: match existing dispatcher style
- Rust: `cargo fmt` + `cargo clippy`

## Releasing

All SDKs share a single version from the root `VERSION` file.

1. Update `VERSION`:
   ```bash
   echo "0.4.0" > VERSION
   ```

2. Sync all SDK version strings:
   ```bash
   bash scripts/bump-version.sh 0.4.0
   ```

3. Commit, tag, and push — the release workflow triggers automatically on tag push:
   ```bash
   git add -A
   git commit -m "chore: bump version to 0.4.0"
   git tag v0.4.0
   git push origin main --tags
   ```
   This builds all targets (iOS, macOS, Android, JVM, WASM, native), tests all SDKs,
   and publishes to GitHub Releases, Maven Central, and npm.
   The workflow can also be triggered manually via `workflow_dispatch` for dry runs.

### Local Release

Not supported — all releases go through the unified GitHub Actions workflow
to ensure consistency across all SDKs.
