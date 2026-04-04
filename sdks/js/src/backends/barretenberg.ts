import type { BackendBinding, ProverScheme, VerifierScheme } from "../types.js";

/**
 * Barretenberg backend adapter for browser (WASM).
 *
 * Wraps @aztec/bb.js to provide the standard BackendBinding interface.
 * For Node.js, the native addon handles Barretenberg directly via the
 * C dispatcher — this adapter is browser-only.
 */
export class BarretenbergBinding implements BackendBinding {
  async init(): Promise<void> {
    // TODO: Import and initialize @aztec/bb.js
    throw new Error("Barretenberg WASM binding not yet implemented");
  }

  async prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array> {
    throw new Error("Not implemented");
  }

  async verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean> {
    throw new Error("Not implemented");
  }

  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    throw new Error("Not implemented");
  }

  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    throw new Error("Not implemented");
  }
}
