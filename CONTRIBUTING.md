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

2. Update `sdks/js/package.json` version field to match.

3. Commit and tag:
   ```bash
   git add VERSION sdks/js/package.json
   git commit -m "chore: bump version to 0.4.0"
   git tag v0.4.0
   git push origin main --tags
   ```

4. Trigger release workflows manually via GitHub Actions UI (`workflow_dispatch`):
   - **Swift**: Release Swift SDK — builds XCFramework, creates GitHub release
   - **Kotlin**: Release Kotlin SDK — publishes to Maven Central
   - **JS**: Release JS SDK — publishes to npm

   Each workflow supports a `dry_run` option to validate without publishing.

### Local Release

If GitHub Actions is not available:

```bash
# Swift
make release-swift

# Kotlin (requires GPG + Sonatype credentials)
make release-kotlin

# JS (requires NPM_TOKEN)
make release-js
```
