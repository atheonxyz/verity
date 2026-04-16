import { VerityError, VerityErrorCode } from "../errors.js";
import type { BackendBinding, BackendOptions, ProverScheme, VerifierScheme } from "../types.js";

/**
 * Barretenberg backend adapter for browser (WASM).
 *
 * Wraps @aztec/bb.js to provide the standard BackendBinding interface.
 * Not yet implemented — placeholder for future work.
 */
export class BarretenbergBinding implements BackendBinding {
  async init(_options?: BackendOptions): Promise<void> {
    throw new VerityError(
      VerityErrorCode.BACKEND_UNAVAILABLE,
      "Barretenberg WASM binding not yet implemented",
    );
  }

  async loadProver(_data: Uint8Array): Promise<ProverScheme> {
    throw new VerityError(
      VerityErrorCode.BACKEND_UNAVAILABLE,
      "Barretenberg WASM binding not yet implemented",
    );
  }

  async loadVerifier(_data: Uint8Array): Promise<VerifierScheme> {
    throw new VerityError(
      VerityErrorCode.BACKEND_UNAVAILABLE,
      "Barretenberg WASM binding not yet implemented",
    );
  }
}
