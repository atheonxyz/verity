/**
 * Node.js entry point.
 *
 * The current JS SDK uses the same ProveKit WASM backend in Node.js and the
 * browser. Native addon integration can be added later without changing the
 * public API.
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, BackendOptions } from "./types.js";
export { Proof } from "./proof.js";
export { VerityError, VerityErrorCode } from "./errors.js";
