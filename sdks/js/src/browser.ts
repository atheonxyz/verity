/**
 * Browser entry point — uses WASM or vendor JS for proving backends.
 *
 * Each backend provides its own WASM binding (compiled from Rust)
 * or wraps a vendor JS package (e.g., @aztec/bb.js for Barretenberg).
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, BackendOptions } from "./types.js";
export { Proof } from "./proof.js";
export { VerityError, VerityErrorCode } from "./errors.js";
