# Building & Testing

## Prerequisites

- **Rust**: nightly toolchain (`rustup install nightly`)
- **Xcode**: 16+ (for iOS builds)
- **Android NDK**: via Android Studio or standalone
- **Node.js**: 20+ (for JS SDK)
- **wasm-pack**: `cargo install wasm-pack` (for WASM builds)

## Building Core

```bash
# iOS (requires macOS + Xcode)
make core-ios PROVEKIT_PATH=../provekit

# Android
make core-android

# WASM
make core-wasm

# Host native (for testing)
make core-native
```

## Testing

```bash
# Swift SDK
make test-swift

# Kotlin SDK
make test-kotlin

# JS SDK
cd sdks/js && npm install && npm test

# All
make test-all
```

## Project Structure

```
core/               # Shared C + Rust code
├── dispatcher/     # C vtable router
├── include/        # Public C headers
├── backends/       # Rust FFI crates
└── build/          # Per-target build scripts

sdks/
├── swift/          # iOS SDK
├── kotlin/         # Android SDK
└── js/             # JS SDK (Node + browser)
```
