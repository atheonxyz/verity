import { VerityError, VerityErrorCode } from "./errors.js";

/**
 * A zero-knowledge proof.
 *
 * Wraps the raw proof bytes with convenience accessors.
 * Created by {@link ProverScheme.prove}, consumed by {@link VerifierScheme.verify}.
 */
export class Proof {
  readonly data: Uint8Array;
  readonly size: number;
  readonly hex: string;

  private constructor(data: Uint8Array) {
    this.data = new Uint8Array(data);
    this.size = this.data.length;
    this.hex = Array.from(this.data, (b) => b.toString(16).padStart(2, "0")).join("");
  }

  /** Truncated hex string for display. */
  hexPreview(maxBytes = 32): string {
    const slice = this.data.slice(0, maxBytes);
    const preview = Array.from(slice, (b) => b.toString(16).padStart(2, "0")).join("");
    return this.data.length > maxBytes ? preview + "..." : preview;
  }

  /** Create a proof from raw bytes. */
  static fromBytes(data: Uint8Array): Proof {
    if (data.length === 0) {
      throw new VerityError(VerityErrorCode.INVALID_INPUT, "proof data cannot be empty");
    }
    return new Proof(data);
  }

  toString(): string {
    return `Proof(${this.size} bytes)`;
  }
}
