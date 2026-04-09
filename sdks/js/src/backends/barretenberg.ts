import type { BackendBinding, BackendOptions, ProverScheme, VerifierScheme } from "../types.js";

/**
 * Barretenberg backend adapter for browser (WASM).
 *
 * Wraps @aztec/bb.js to provide the standard BackendBinding interface.
 * Not yet implemented — placeholder for future work.
 */
export class BarretenbergBinding implements BackendBinding {
  async init(_options?: BackendOptions): Promise<void> {
    throw new Error("Barretenberg WASM binding not yet implemented");
  }

  async loadProver(_data: Uint8Array): Promise<ProverScheme> {
    throw new Error("Not implemented");
  }

  async loadVerifier(_data: Uint8Array): Promise<VerifierScheme> {
    throw new Error("Not implemented");
  }
}
