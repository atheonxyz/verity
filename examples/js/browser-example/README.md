# Verity Browser Demo

Zero-knowledge proof generation and verification in the browser using the Verity SDK with ProveKit WASM.

## Prerequisites

- Circuit artifacts (`.pkp`, `.pkv`, `inputs.json`) — generate with `make test-fixtures` or the ProveKit CLI
- Node.js (for the dev server)
- ProveKit WASM built (`make core-wasm` from repo root)

## Setup

```bash
# From the repo root
make core-wasm        # Build ProveKit WASM artifacts
make test-fixtures    # Generate test circuit artifacts

# Set up the example
cd examples/js/browser-example
npm install
mkdir -p artifacts
cp ../../../circuits/fixtures/sha256/*.pkp artifacts/prover.pkp
cp ../../../circuits/fixtures/sha256/*.pkv artifacts/verifier.pkv
cp ../../../circuits/fixtures/sha256/inputs.json artifacts/
```

## Run

```bash
npm run serve
# Open http://localhost:3000
```

The server sets Cross-Origin Isolation headers (`COOP` + `COEP`) required for `SharedArrayBuffer` and WASM multi-threading.

## What it does

1. **Initialize** — Loads the ProveKit WASM module, sets up thread pool
2. **Load** — Fetches `.pkp`/`.pkv` artifacts, creates prover and verifier
3. **Prove** — Generates a zero-knowledge proof from circuit inputs (witness generation via noir_js)
4. **Verify** — Verifies the proof is mathematically valid

## Usage pattern

```js
import { Verity, Backend } from "@atheon/verity";

const verity   = await Verity.create(Backend.ProveKit);
const prover   = await verity.loadProver(pkpBytes);
const verifier = await verity.loadVerifier(pkvBytes);
const proof    = await prover.prove({ x: "1", y: "2" });
const valid    = await verifier.verify(proof);

prover.dispose();
verifier.dispose();
```
