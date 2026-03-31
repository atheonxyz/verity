# Building & Testing

## Prerequisites

- **Rust**: nightly toolchain (`rustup install nightly`)
- **Xcode**: 16+ (for iOS builds)
- **Android NDK**: via Android Studio or standalone
- **Node.js**: 20+ (for JS SDK)
- **wasm-pack**: `cargo install wasm-pack` (for WASM builds)
- **gh CLI**: for releases (`brew install gh`)

### Rust targets

```bash
# iOS
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# Android
rustup target add aarch64-linux-android x86_64-linux-android

# WASM
rustup target add wasm32-unknown-unknown
```

## Building Core

All iOS and Android builds require a sibling ProveKit checkout:

```bash
# iOS (device + simulator xcframework)
make core-ios PROVEKIT_PATH=../provekit

# Android NDK
make core-android PROVEKIT_PATH=../provekit

# WASM (browser)
make core-wasm

# Host native (for testing / Node.js N-API)
make core-native

# All targets
make core-all PROVEKIT_PATH=../provekit
```

The default cargo profile is `release-mobile` (size-optimized). Override with:

```bash
CARGO_PROFILE=release make core-ios PROVEKIT_PATH=../provekit
```

## Testing

```bash
# All platforms
make test-all

# Individual
make test-swift                          # xcodebuild test (iPhone 16 simulator)
make test-kotlin                         # ./gradlew connectedAndroidTest
make test-js                             # vitest run

# JS SDK standalone
cd sdks/js && npm install && npm test
cd sdks/js && npm run test:watch         # watch mode
```

## Linting & Formatting

```bash
# Lint (Rust clippy + TypeScript type check)
make lint

# Format (Rust fmt + JS prettier)
make fmt

# Full check (lint + compile verification)
make check
```

## Releasing

Release scripts live in `core/release/`. The Makefile wires them up:

```bash
make release-swift                       # zip xcframework + checksum + gh command
make release-kotlin                      # publish to Maven Central (needs GPG + Sonatype env vars)
make release-js                          # publish to npm (needs NPM_TOKEN)
```

See [release.md](release.md) for the full release process.

## Cleaning

```bash
make clean
```

## Utilities

```bash
make version                             # print current version from VERSION file
```

## Project Structure

```
core/
├── build/          # Per-target build scripts (build-ios.sh, build-android.sh, etc.)
├── release/        # Per-platform release scripts (release-ios.sh, release-android.sh, etc.)
├── dispatcher/     # C vtable router (verity_dispatch.c)
├── include/        # Public C headers (verity_ffi.h, verity_ffi_raw.h)
└── backends/       # Rust FFI crates (barretenberg/)

sdks/
├── swift/          # iOS SDK (SPM)
├── kotlin/         # Android SDK (Gradle)
└── js/             # JS SDK (Node + browser)
```

## Platform Notes

- `sdks/swift` defaults to `VERITY_SWIFT_SDK_MODE=source-only`, which validates the Swift wrapper and public API without linking the iOS xcframework.
- `VERITY_SWIFT_SDK_MODE=native` is reserved for environments where `output/Verity.xcframework` has already been built and linked in an Apple-native workflow. The native mobile artifact currently bundles the ProveKit backend only; use Xcode's iOS simulator test runner for native verification.
- `sdks/swift/VerityDispatch` is a symlink to `core/dispatcher`, so the Swift package and core C dispatcher share one source of truth.
- The published Kotlin AAR currently ships `arm64-v8a` JNI libraries only.
- `core/build/build-android.sh` builds a stripped ProveKit `.so` for `arm64-v8a` by default and accepts `VERITY_ANDROID_ABIS=arm64-v8a,x86_64` to produce additional ABI outputs.
