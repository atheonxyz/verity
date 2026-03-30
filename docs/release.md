# Releasing

## Version

All SDKs share a single version from the root `VERSION` file.

## Process

1. Update `VERSION`:
   ```bash
   echo "0.3.0" > VERSION
   ```

2. Update `sdks/js/package.json` version field to match.

3. Commit and tag:
   ```bash
   git add VERSION sdks/js/package.json
   git commit -m "chore: bump version to 0.3.0"
   git tag v0.3.0
   git push origin main --tags
   ```

4. CI automatically:
   - Builds core for all targets
   - Runs all SDK tests
   - Publishes Swift SDK (GitHub release with XCFramework)
   - Publishes Kotlin SDK (Maven Central)
   - Publishes JS SDK (npm)

## Manual Release

If CI is not available:

```bash
# Swift
make release-swift

# Kotlin
make release-kotlin

# JS
make release-js
```
