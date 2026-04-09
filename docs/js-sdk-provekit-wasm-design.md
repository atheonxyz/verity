# JS/TS SDK — ProveKit WASM Backend

**Date:** 2026-04-08
**Status:** Approved
**Scope:** Browser-only ProveKit backend via WASM. Node.js and Barretenberg deferred.

## Goal

Implement the ProveKit proving backend for the JS/TypeScript SDK using ProveKit's existing WASM crate (`tooling/provekit-wasm/`). Users can generate and verify zero-knowledge proofs in the browser with a single `npm install`.

## Usage

```ts
import { Verity, Backend, Proof } from "@atheon/verity";

const verity   = await Verity.create(Backend.ProveKit);
const prover   = await verity.loadProver(pkpBytes);   // Uint8Array from .pkp file
const verifier = await verity.loadVerifier(pkvBytes);  // Uint8Array from .pkv file

const proof = await prover.prove({ x: "1", y: "2" });
const valid = await verifier.verify(proof);

prover.dispose();
verifier.dispose();
```

This matches the Swift and Kotlin SDK patterns:
- `Verity` is a factory — loads provers/verifiers, initializes backends.
- `ProverScheme` owns `prove()` — primary API, not a convenience.
- `VerifierScheme` owns `verify()` — primary API.
- `Verity.prove()` / `Verity.verify()` exist as convenience delegators.

## Breaking Changes

This spec changes the existing (never-functional) JS SDK API. All current `prove()`/`verify()` methods throw "not yet implemented", so there are no real consumers to break. Changes:

- `Verity.prove()` now returns `Promise<Proof>` instead of `Promise<Uint8Array>`.
- `Verity.verify()` now accepts `Proof` instead of `Uint8Array`.
- `ProverScheme` gains `prove()`, `VerifierScheme` gains `verify()`.
- `ProverScheme`/`VerifierScheme` lose `save(path)` (browser-only, no file system).
- `BackendBinding` loses `prove()`/`verify()` (logic moves to scheme implementations).

## Error Code Fix

The existing `errors.ts` has `BACKEND_UNAVAILABLE = 10`, but the C FFI defines `VERITY_OUT_OF_MEMORY = 10`. Swift and Kotlin both map code 10 to OutOfMemory. This is a pre-existing bug.

Fix as part of this work:
- Add `OUT_OF_MEMORY = 10` (matching C FFI).
- Move `BACKEND_UNAVAILABLE` to `11` (JS-only, no C counterpart).
- Add `RESOURCE_CLOSED = -2` (JS-only, for use-after-dispose — matches Swift's `.resourceClosed` and Kotlin's `check(!closed)`).

## Public API

### Verity (factory)

```ts
class Verity {
  static readonly version: string;

  static async create(backend: Backend, options?: BackendOptions): Promise<Verity>;

  get backend(): Backend;

  loadProver(data: Uint8Array): Promise<ProverScheme>;
  loadVerifier(data: Uint8Array): Promise<VerifierScheme>;

  // Convenience — delegates to prover.prove() / verifier.verify()
  prove(prover: ProverScheme, inputs: Record<string, unknown> | string): Promise<Proof>;
  verify(verifier: VerifierScheme, proof: Proof): Promise<boolean>;
}
```

Input validation: `loadProver()` / `loadVerifier()` throw `INVALID_INPUT` on empty `Uint8Array`, matching Swift/Kotlin behavior.

### ProverScheme

```ts
interface ProverScheme {
  prove(inputs: Record<string, unknown> | string): Promise<Proof>;
  serialize(): Promise<Uint8Array>;
  dispose(): void;
}
```

- `inputs` — Circuit inputs as a plain object (matching the circuit ABI) or a JSON string.
- `prove()` handles witness generation internally via noir_js, then calls ProveKit WASM.
- Reusable — can be called multiple times (internally reconstructs WASM Prover each call).
- `serialize()` — returns the prover scheme as serialized bytes (same format as `.pkp` files). For the ProveKit WASM backend, this returns the original bytes passed to `loadProver()`.
- `dispose()` — releases references. Safe to call multiple times. After `dispose()`, calling `prove()` or `serialize()` throws `VerityError(RESOURCE_CLOSED)`. Internally: `private disposed = false` flag, checked at entry to every method.

### VerifierScheme

```ts
interface VerifierScheme {
  verify(proof: Proof): Promise<boolean>;
  serialize(): Promise<Uint8Array>;
  dispose(): void;
}
```

- `verify()` returns `true` if valid, `false` if mathematically invalid.
- Reusable — ProveKit WASM Verifier clones internally.
- `serialize()` — returns the original `.pkv` bytes.
- After `dispose()`, calling `verify()` or `serialize()` throws `VerityError(RESOURCE_CLOSED)`.

### Proof

```ts
class Proof {
  readonly data: Uint8Array;
  readonly size: number;
  readonly hex: string;

  hexPreview(maxBytes?: number): string;

  static fromBytes(data: Uint8Array): Proof;
}
```

Matches the Swift/Kotlin `Proof` type. Wraps raw proof bytes (JSON-serialized internally by ProveKit).

### BackendOptions

```ts
interface BackendOptions {
  /** Override the bundled WASM module URL. */
  wasmUrl?: string;
  /** Thread count override. false = single-threaded. Default: auto-detect. */
  threads?: number | false;
}
```

### No Witness Type

Unlike Swift/Kotlin, the JS SDK does **not** have a `Witness` wrapper class. Reasons:
- No file system in browser (TOML file paths don't apply).
- Plain objects and JSON strings are idiomatic JS.
- The `inputs` parameter on `prove()` accepts both directly.

## Internal Architecture

### Layer Diagram

```
Verity.create(Backend.ProveKit)
  └─ resolveBinding() → dynamic import("./backends/provekit.js")
       └─ ProveKitBinding implements BackendBinding
            ├─ init(): load WASM module (singleton), init panic hook, auto-detect threads
            ├─ loadProver(bytes): extract circuit JSON, return ProveKitProverScheme
            ├─ loadVerifier(bytes): create WASM Verifier, return ProveKitVerifierScheme
            │
            ├─ ProveKitProverScheme
            │    ├─ stored: raw pkp bytes, cached circuit JSON, ref to WASM module + noir_js
            │    └─ prove(inputs):
            │         1. Noir(circuitJson).execute(inputs) → compressed witness
            │         2. decompressWitnessStack(compressed) → witnessMap
            │         3. Convert witnessMap to { index: "0xhex" } format
            │         4. new Prover(storedPkpBytes)  ← reconstruct (consumed per call)
            │         5. prover.proveBytes(converted) → proof JSON bytes
            │         6. return Proof(bytes)
            │
            └─ ProveKitVerifierScheme
                 ├─ stored: WASM Verifier handle (reusable), raw pkv bytes
                 └─ verify(proof):
                      1. verifier.verifyBytes(proof.data)
                      2. return true (or catch PROOF_ERROR → false)
```

### Key Design Decisions

**1. Use ProveKit's WASM crate directly, not Verity's own WASM wrapper.**

ProveKit already ships a production-quality WASM crate (`tooling/provekit-wasm/`) with:
- Binary format parsing (`.pkp`/`.pkv` with Zstd/XZ decompression)
- Thread pool via `wasm-bindgen-rayon`
- Witness map parsing (Map or plain object)
- Circuit extraction (`getCircuit()`)

The existing `sdks/js/wasm/verity_wasm.rs` stub should be deleted. There is no reason to re-wrap what ProveKit already provides.

**2. Prover is reconstructed per prove() call.**

ProveKit's WASM `Prover` is consumed after `proveBytes()` (`self.inner.take()`). To expose a reusable `ProverScheme` (matching Swift/Kotlin), we store the original `.pkp` bytes and construct a fresh WASM `Prover` for each `prove()` call.

Cost: decompression + deserialization (~10-100ms for a few MB). Proving itself takes seconds, so overhead is negligible.

**3. noir_js handles witness generation.**

The native SDKs pass high-level inputs to the C backend, which generates witnesses internally. ProveKit's WASM crate only accepts pre-computed witness maps. The SDK bridges this gap using `@noir-lang/noir_js` to:
1. Encode inputs via circuit ABI
2. Execute ACVM to produce witness
3. Decompress and convert witness to ProveKit's expected format

This is the same flow as ProveKit's own wasm-demo.

**4. WASM module is a global singleton.**

Matches Swift/Kotlin pattern where backends are initialized once globally. The WASM module and thread pool are shared across all `Verity` instances using `Backend.ProveKit`. The WASM module and thread pool live for the lifetime of the page — there is no teardown API. This is intentional and matches how native backends work (initialized once, never torn down).

**5. Threading auto-detects with graceful fallback.**

On init:
1. Check `SharedArrayBuffer` availability
2. Detect platform (iOS WebKit has unreliable WASM threading → skip)
3. Try `initThreadPool(navigator.hardwareConcurrency)` → catch and fallback to single-threaded
4. User can override via `{ threads: N }` or `{ threads: false }`

Requires server to set `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers.

### resolveBinding()

```ts
private static async resolveBinding(backend: Backend): Promise<BackendBinding> {
  switch (backend) {
    case Backend.ProveKit: {
      const { ProveKitBinding } = await import("./backends/provekit.js");
      return new ProveKitBinding();
    }
    case Backend.Barretenberg: {
      const { BarretenbergBinding } = await import("./backends/barretenberg.js");
      return new BarretenbergBinding();
    }
    default:
      throw new VerityError(VerityErrorCode.UNKNOWN_BACKEND);
  }
}
```

Dynamic imports ensure unused backends are never loaded.

### Witness Conversion

ProveKit WASM expects witness as `{ index: "0xhex" }`. noir_js produces a `Map<Witness, FieldElement>` (where Witness wraps an index, FieldElement is a hex string). The conversion:

```ts
function convertWitnessMap(witnessMap: Map<any, string>): Record<number, string> {
  const result: Record<number, string> = {};
  for (const [witness, value] of witnessMap.entries()) {
    const index = typeof witness === "number"
      ? witness
      : typeof witness?.inner === "number"
        ? witness.inner
        : Number(witness);
    if (Number.isNaN(index)) {
      throw new VerityError(
        VerityErrorCode.WITNESS_READ_ERROR,
        `Failed to extract witness index from key: ${witness}`
      );
    }
    result[index] = value;
  }
  return result;
}
```

Targets `@noir-lang/noir_js` ≥1.0.0-beta.11. If noir_js changes its `Witness` type internals, the `NaN` guard catches it with a clear error instead of silently producing corrupt data.

### Error Mapping

ProveKit WASM throws `JsError` (via `wasm-bindgen`). The SDK catches and maps to `VerityError`:

| WASM error message pattern | VerityErrorCode |
|---|---|
| "Failed to parse prover" | SCHEME_READ_ERROR |
| "Failed to parse verifier" | SCHEME_READ_ERROR |
| "Failed to generate proof" | PROOF_ERROR |
| "Failed to parse proof" | INVALID_INPUT |
| "Witness map is empty" | WITNESS_READ_ERROR |
| "Failed to parse witness" | WITNESS_READ_ERROR |
| "Failed to parse hex" | WITNESS_READ_ERROR |
| Other | PROOF_ERROR (default) |

## File Structure

```
sdks/js/
  src/
    index.ts                — barrel exports (add Proof)
    verity.ts               — update resolveBinding(), add options param, add convenience methods
    types.ts                — update ProverScheme/VerifierScheme interfaces, add Proof class
    errors.ts               — unchanged
    browser.ts              — browser entry point (unchanged)
    node.ts                 — node entry point (unchanged, stub)
    backends/
      provekit.ts           — ProveKitBinding, ProveKitProverScheme, ProveKitVerifierScheme
      barretenberg.ts       — unchanged stub
  wasm/                     — pre-built ProveKit WASM artifacts (git-ignored, built by make core-wasm)
    provekit_wasm.js        — wasm-bindgen JS glue
    provekit_wasm_bg.wasm   — WASM binary
    snippets/               — wasm-bindgen-rayon worker helpers
  package.json              — add peerDependencies, update files[]
  tsconfig.json             — unchanged
  tsup.config.ts            — new: configure WASM asset copying
```

### Changes to Existing Files

| File | Change |
|---|---|
| `src/types.ts` | Add `prove()` to ProverScheme, `verify()` to VerifierScheme, add `Proof` class, add `BackendOptions`, remove `save()`. Simplify `BackendBinding` to: `init(options?: BackendOptions): Promise<void>`, `loadProver(data: Uint8Array): Promise<ProverScheme>`, `loadVerifier(data: Uint8Array): Promise<VerifierScheme>`. Remove `prove()`/`verify()` from the interface. |
| `src/verity.ts` | Implement `resolveBinding()`, add `options` param to `create()`, add `static version`, add convenience `prove()`/`verify()` that delegate to `prover.prove()` / `verifier.verify()` |
| `src/errors.ts` | Fix error code 10 collision: add `OUT_OF_MEMORY = 10`, move `BACKEND_UNAVAILABLE` to `11`, add `RESOURCE_CLOSED = -2` |
| `src/index.ts` | Export `Proof`, `BackendOptions` |
| `src/backends/barretenberg.ts` | Update to match new `BackendBinding` interface (remove `prove()`/`verify()` stubs) |
| `package.json` | Add `peerDependencies` for noir_js/acvm_js, update `files[]` |
| `sdks/js/wasm/verity_wasm.rs` | Delete (replaced by pre-built ProveKit WASM) |
| `sdks/js/wasm/Cargo.toml` | Delete |

### New Files

| File | Purpose |
|---|---|
| `src/backends/provekit.ts` | ProveKitBinding + scheme implementations (~200-300 lines) |
| `tsup.config.ts` | Build config: dual browser/node entry, WASM asset copying |

## Dependencies

### Peer Dependencies (new)

```json
{
  "peerDependencies": {
    "@noir-lang/noir_js": ">=1.0.0-beta.11",
    "@noir-lang/acvm_js": ">=1.0.0-beta.11"
  },
  "peerDependenciesMeta": {
    "@noir-lang/noir_js": { "optional": true },
    "@noir-lang/acvm_js": { "optional": true }
  }
}
```

Marked optional so the package installs cleanly for Node.js users who don't need browser WASM. Required at runtime for `Backend.ProveKit` in browser. `ProveKitBinding.init()` catches the dynamic import failure and throws a clear error:

```
VerityError(BACKEND_UNAVAILABLE, "ProveKit browser backend requires @noir-lang/noir_js and @noir-lang/acvm_js. Install with: npm install @noir-lang/noir_js @noir-lang/acvm_js")
```

### Dev Dependencies (new)

- None required beyond existing tsup/vitest/typescript.

## Build Pipeline

### WASM Artifacts

`make core-wasm` (updated) builds ProveKit WASM and stages to `sdks/js/wasm/`:

1. Clone/update ProveKit if not present (`provekit/` at repo root)
2. `cargo build --release --target wasm32-unknown-unknown -p provekit-wasm -Z build-std=panic_abort,std`
3. `wasm-bindgen --target web --out-dir sdks/js/wasm/ ...`
4. Copy snippets, patch worker helper imports

The `wasm/` directory is `.gitignore`d — built artifacts, not source.

### tsup Build

`tsup.config.ts` configures:
- Browser entry: `src/browser.ts` → `dist/browser/`
- Node entry: `src/node.ts` → `dist/node/`
- Copy `wasm/` to `dist/wasm/` (via esbuild copy plugin or post-build script)
- External: `@noir-lang/*` (peer deps, not bundled)

### npm Package

`files` in `package.json`:
```json
["dist/", "README.md"]
```

tsup copies `wasm/` into `dist/wasm/` during build. Only `dist/` ships in the npm package — no duplication.

## Testing Strategy

### Unit Tests (vitest, no WASM)

- `Proof` class: construction, hex encoding, size, fromBytes
- Error mapping: WASM error messages → VerityErrorCode
- Witness conversion: Map → `{ index: "0xhex" }` format
- `Verity.create()` with unknown backend → throws

### Integration Tests (vitest, with WASM)

Requires pre-built WASM artifacts and test fixtures (`.pkp`, `.pkv`, `inputs.json`):

- `Verity.create(Backend.ProveKit)` → initializes without error
- `loadProver(pkpBytes)` → returns ProverScheme
- `loadVerifier(pkvBytes)` → returns VerifierScheme
- `prover.prove(inputs)` → returns Proof with non-empty data
- `verifier.verify(proof)` → returns true
- `verifier.verify(tamperedProof)` → returns false
- `prover.prove()` called twice → both succeed (reusability)
- `prover.dispose()` then `prove()` → throws
- Invalid `.pkp` bytes → throws SCHEME_READ_ERROR

### Test Fixtures

Use `make test-fixtures` (existing) which generates `.pkp`/`.pkv` from circuit.json. Test circuits live in `circuits/fixtures/`.

## Cross-Origin Isolation

Threading requires specific HTTP headers. Document in README:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without these headers, SharedArrayBuffer is unavailable and the SDK falls back to single-threaded proving (slower but functional).

## Out of Scope

- **Node.js backend** — N-API binding for native performance. Separate effort.
- **Barretenberg browser backend** — `@aztec/bb.js` vendor adapter. Separate effort.
- **TOML input parsing** — Browser users pass JSON objects, not TOML files.
- **`save(path)` on ProverScheme/VerifierScheme** — No file system in browser. Add for Node later.
- **Web Worker offloading** — Running prove() in a dedicated worker. Users can do this themselves; the SDK doesn't force it.
- **Streaming/progress** — No progress callbacks during proving. ProveKit WASM doesn't expose this.
