# Circuits

Source circuits are organized by flavour so the repo can host multiple implementations side by side.

## Layout

- `noir/` contains Noir source circuits and their local build artifacts.
- `circom/` is reserved for Circom-based circuits.
- `rust/` is reserved for Rust-based circuits.
- `fixtures/` contains reusable compiled assets and sample inputs consumed by SDK tests and examples.

Use `circuits/<flavour>/<circuit-name>/` for source projects. Keep backend- or SDK-facing fixture files under `circuits/fixtures/` unless they are specific to a single flavour and circuit.
