# Examples

## BasicProof

Minimal Android app demonstrating the prepare → prove → verify flow.

### Prerequisites

- Android Studio Hedgehog (2023.1) or later
- Android SDK 34
- A compiled Noir circuit (`circuit.json`) and input file (`Prover.toml`)
- Native libraries already built (`bash ../../scripts/build-android.sh`)

### Run

1. Copy your circuit files into the app assets:

```bash
cp circuit.json  Examples/BasicProof/app/src/main/assets/
cp Prover.toml   Examples/BasicProof/app/src/main/assets/
```

2. Open `Examples/BasicProof/` in Android Studio.

3. Select a device or emulator and run.
