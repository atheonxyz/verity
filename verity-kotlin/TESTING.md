# Verity Android — Testing Guide

## Prerequisites

- Android NDK (set `ANDROID_NDK_HOME`)
- Rust with Android targets: `rustup target add aarch64-linux-android x86_64-linux-android`
- `provekit` repo checked out alongside this repo (or set `PROVEKIT_ROOT`)

## Building Native Libraries

```bash
# From verity-kotlin/
bash scripts/build-android.sh
```

This compiles the Rust FFI crates for Android targets, builds the JNI bridge,
and places the resulting `.so` files in `src/main/jniLibs/<abi>/`.

## Running Tests

Copy the test fixtures from the Swift SDK into the Android test assets:

```bash
cp ../verity/Tests/VerityTests/Fixtures/circuit.json   src/androidTest/assets/fixtures/
cp ../verity/Tests/VerityTests/Fixtures/Prover.toml     src/androidTest/assets/fixtures/
```

Then run the instrumented tests on a connected device or emulator:

```bash
./gradlew :verity-kotlin:connectedAndroidTest
```

## Releasing

1. Build the release AAR: `./gradlew :verity-kotlin:assembleRelease`
2. Publish: `bash scripts/release.sh <version>`
