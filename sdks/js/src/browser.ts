/**
 * Browser entry point — uses WASM or vendor JS for proving backends.
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, BackendOptions } from "./types.js";
export { Proof } from "./proof.js";
export { VerityError, VerityErrorCode } from "./errors.js";
