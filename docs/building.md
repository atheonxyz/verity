# Building & Testing

## Prerequisites

- **Rust**: nightly toolchain (`rustup install nightly`)
- **Xcode**: 16+ (for iOS builds)
- **Android NDK**: via Android Studio or standalone
- **Node.js**: 20+ (for JS SDK)
- **wasm-pack**: `cargo install wasm-pack` (for WASM builds)
- **ProveKit**: clone the [provekit](https://github.com/aspect-build/provekit) repo and checkout branch `ash/v1-ffi-sdk`

## Building Core

The iOS and Android builds require the ProveKit repo as a sibling directory (or pass `PROVEKIT_PATH`).

```bash
# Clone provekit (one-time setup)
git clone https://github.com/aspect-build/provekit ../provekit
cd ../provekit && git checkout ash/v1-ffi-sdk && cd -

# iOS (requires macOS + Xcode) — builds staticlib
make core-ios PROVEKIT_PATH=../provekit

# Android — builds cdylib (.so) for provekit-ffi
make core-android PROVEKIT_PATH=../provekit

# WASM
make core-wasm

# Host native (for testing)
make core-native
```

## Testing

```bash
# Swift SDK source-only unit tests (default)
make test-swift

# Swift SDK native iOS simulator integration tests (requires output/Verity.xcframework)
cd sdks/swift
xcodebuild -scheme Verity -showdestinations
VERITY_SWIFT_SDK_MODE=native xcodebuild test -scheme Verity -destination 'platform=iOS Simulator,name=<available simulator>'

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

## Platform Notes

- `sdks/swift` defaults to `VERITY_SWIFT_SDK_MODE=source-only`, which validates the Swift wrapper and public API without linking the iOS xcframework.
- `VERITY_SWIFT_SDK_MODE=native` is reserved for environments where `output/Verity.xcframework` has already been built and linked in an Apple-native workflow. The native mobile artifact currently bundles the ProveKit backend only; use Xcode’s iOS simulator test runner for native verification.
- `sdks/swift/VerityDispatch` is a symlink to `core/dispatcher`, so the Swift package and core C dispatcher share one source of truth.
- The published Kotlin AAR currently ships `arm64-v8a` JNI libraries only.
- `core/build/build-android.sh` builds a stripped ProveKit `.so` for `arm64-v8a` by default and accepts `VERITY_ANDROID_ABIS=arm64-v8a,x86_64` to produce additional ABI outputs.
