/**
 * Node.js entry point — uses N-API native addon for FFI.
 *
 * The native addon (verity_napi.node) provides synchronous bindings
 * to the C dispatcher, wrapped in async for API consistency.
 */

export { Verity } from "./verity.js";
export { Backend } from "./types.js";
export type { ProverScheme, VerifierScheme, PreparedScheme } from "./types.js";
export { VerityError, VerityErrorCode } from "./errors.js";

// TODO: Wire up N-API binding in Verity.resolveBinding()
// The native addon will be built from native/verity_napi.c
