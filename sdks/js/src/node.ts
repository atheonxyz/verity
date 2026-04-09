/**
 * Node.js entry point — uses N-API native addon for FFI.
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, BackendOptions } from "./types.js";
export { Proof } from "./proof.js";
export { VerityError, VerityErrorCode } from "./errors.js";

// TODO: Wire up N-API binding in Verity.resolveBinding()
