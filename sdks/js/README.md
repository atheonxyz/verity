# Verity JS SDK

JavaScript and TypeScript bindings for Verity.

The package supports:

- Browser proving and verification through the ProveKit WASM backend
- Node.js proving and verification through the same ProveKit WASM path

Before building or running the browser backend from this repo, generate the WASM
artifacts:

```bash
make core-wasm
```

To generate `.pkp` / `.pkv` fixtures for tests or the demo, use ProveKit
directly:

```bash
bash scripts/generate-js-artifacts.sh
```
