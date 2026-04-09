import type { Proof } from "./proof.js";

/** Available proving backends. */
export enum Backend {
  /** ProveKit WHIR backend (transparent, hash-based). */
  ProveKit = 0,
  /** Barretenberg UltraHonk backend (KZG commitments). */
  Barretenberg = 1,
}

/** Options for backend initialization. */
export interface BackendOptions {
  /** Override the bundled WASM module URL. */
  wasmUrl?: string;
  /** Thread count override. false = single-threaded. Default: auto-detect. */
  threads?: number | false;
}

/** Opaque handle to a compiled prover scheme. */
export interface ProverScheme {
  /** Generate a proof from circuit inputs. */
  prove(inputs: Record<string, unknown> | string): Promise<Proof>;
  /** Serialize the prover scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release resources. Safe to call multiple times. */
  dispose(): void;
}

/** Opaque handle to a compiled verifier scheme. */
export interface VerifierScheme {
  /** Verify a proof. Returns true if valid, false if mathematically invalid. */
  verify(proof: Proof): Promise<boolean>;
  /** Serialize the verifier scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release resources. Safe to call multiple times. */
  dispose(): void;
}

/** Backend binding interface — implemented per runtime (Node/WASM/vendor). */
export interface BackendBinding {
  init(options?: BackendOptions): Promise<void>;
  loadProver(data: Uint8Array): Promise<ProverScheme>;
  loadVerifier(data: Uint8Array): Promise<VerifierScheme>;
}
