/** Available proving backends. */
export enum Backend {
  /** ProveKit WHIR backend (transparent, hash-based). */
  ProveKit = 0,
  /** Barretenberg UltraHonk backend (KZG commitments). */
  Barretenberg = 1,
}

/** Opaque handle to a compiled prover scheme. */
export interface ProverScheme {
  /** Save the prover scheme to a file (Node.js only). */
  save(path: string): Promise<void>;
  /** Serialize the prover scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release native resources. */
  dispose(): void;
}

/** Opaque handle to a compiled verifier scheme. */
export interface VerifierScheme {
  /** Save the verifier scheme to a file (Node.js only). */
  save(path: string): Promise<void>;
  /** Serialize the verifier scheme to bytes. */
  serialize(): Promise<Uint8Array>;
  /** Release native resources. */
  dispose(): void;
}

/** Backend binding interface — implemented per runtime (Node/WASM). */
export interface BackendBinding {
  init(): Promise<void>;
  prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array>;
  verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean>;
  loadProver(data: Uint8Array): Promise<ProverScheme>;
  loadVerifier(data: Uint8Array): Promise<VerifierScheme>;
}
