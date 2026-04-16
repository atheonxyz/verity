import { Backend, type BackendBinding, type BackendOptions, type ProverScheme, type VerifierScheme } from "./types.js";
import type { Proof } from "./proof.js";
import { VerityError, VerityErrorCode } from "./errors.js";

/**
 * Verity — zero-knowledge proof SDK.
 *
 * Factory for loading prover and verifier schemes.
 * Use the schemes directly to generate and verify proofs.
 *
 * ```ts
 * const verity   = await Verity.create(Backend.ProveKit);
 * const prover   = await verity.loadProver(pkpBytes);
 * const verifier = await verity.loadVerifier(pkvBytes);
 * const proof    = await prover.prove({ x: "1", y: "2" });
 * const valid    = await verifier.verify(proof);
 * ```
 */
export class Verity {
  static readonly version: string = typeof __VERSION__ === "string" ? __VERSION__ : "0.0.0-dev";

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
  static async create(backend: Backend, options?: BackendOptions): Promise<Verity> {
    const binding = await Verity.resolveBinding(backend);
    await binding.init(options);
    return new Verity(backend, binding);
  }

  private static async resolveBinding(backend: Backend): Promise<BackendBinding> {
    switch (backend) {
      case Backend.ProveKit: {
        const { ProveKitBinding } = await import("./backends/provekit.js");
        return new ProveKitBinding();
      }
      case Backend.Barretenberg: {
        const { BarretenbergBinding } = await import("./backends/barretenberg.js");
        return new BarretenbergBinding();
      }
      default:
        throw new VerityError(VerityErrorCode.UNKNOWN_BACKEND, `Unknown backend: ${backend}`);
    }
  }

  /** Load a prover scheme from bytes (.pkp format). */
  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    if (data.length === 0) {
      throw new VerityError(VerityErrorCode.INVALID_INPUT, "prover data cannot be empty");
    }
    return this.binding.loadProver(data);
  }

  /** Load a verifier scheme from bytes (.pkv format). */
  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    if (data.length === 0) {
      throw new VerityError(VerityErrorCode.INVALID_INPUT, "verifier data cannot be empty");
    }
    return this.binding.loadVerifier(data);
  }

  /** Generate a proof. Convenience — delegates to `prover.prove()`. */
  async prove(prover: ProverScheme, inputs: Record<string, unknown> | string): Promise<Proof> {
    return prover.prove(inputs);
  }

  /** Verify a proof. Convenience — delegates to `verifier.verify()`. */
  async verify(verifier: VerifierScheme, proof: Proof): Promise<boolean> {
    return verifier.verify(proof);
  }
}
