import { Backend, type BackendBinding, type ProverScheme, type VerifierScheme } from "./types.js";
import { VerityError, VerityErrorCode } from "./errors.js";

/**
 * Verity — generate and verify zero-knowledge proofs.
 *
 * Usage:
 * ```ts
 * const verity   = await Verity.create(Backend.Barretenberg);
 * const prover   = await verity.loadProver(proverBytes);
 * const verifier = await verity.loadVerifier(verifierBytes);
 * const proof    = await verity.prove(prover, { a: 1, b: 2 });
 * const valid    = await verity.verify(verifier, proof);
 * ```
 */
export class Verity {
  private binding: BackendBinding;
  private _backend: Backend;

  private constructor(backend: Backend, binding: BackendBinding) {
    this._backend = backend;
    this.binding = binding;
  }

  /** The backend this instance was created with. */
  get backend(): Backend {
    return this._backend;
  }

  /**
   * Create a Verity instance with the specified backend.
   * Initializes the backend (may load WASM or native addon).
   */
  static async create(backend: Backend): Promise<Verity> {
    const binding = await Verity.resolveBinding(backend);
    await binding.init();
    return new Verity(backend, binding);
  }

  private static async resolveBinding(backend: Backend): Promise<BackendBinding> {
    // Dynamic import based on runtime — resolved at build time via package.json exports
    throw new VerityError(
      VerityErrorCode.BACKEND_UNAVAILABLE,
      `Backend ${Backend[backend]} binding not yet implemented`
    );
  }

  /** Generate a proof. */
  async prove(prover: ProverScheme, inputs: string | Record<string, unknown>): Promise<Uint8Array> {
    return this.binding.prove(prover, inputs);
  }

  /** Verify a proof. Returns true if valid. */
  async verify(verifier: VerifierScheme, proof: Uint8Array): Promise<boolean> {
    return this.binding.verify(verifier, proof);
  }

  /** Load a prover scheme from bytes. */
  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    return this.binding.loadProver(data);
  }

  /** Load a verifier scheme from bytes. */
  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    return this.binding.loadVerifier(data);
  }
}
