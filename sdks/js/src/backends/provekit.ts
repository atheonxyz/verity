import type { BackendBinding, BackendOptions, ProverScheme, VerifierScheme } from "../types.js";
import { Proof } from "../proof.js";
import { VerityError, VerityErrorCode } from "../errors.js";

// ---------------------------------------------------------------------------
// WASM module singleton
// ---------------------------------------------------------------------------

let wasmModule: any = null;
let wasmInitialized = false;

// ---------------------------------------------------------------------------
// Utility functions (exported for testing)
// ---------------------------------------------------------------------------

/** Map a WASM JsError to a typed VerityError. */
export function mapWasmError(err: unknown): VerityError {
  const msg = err instanceof Error ? err.message : String(err);

  if (msg.includes("Failed to parse prover") || msg.includes("Failed to parse verifier")) {
    return new VerityError(VerityErrorCode.SCHEME_READ_ERROR, msg);
  }
  if (msg.includes("Failed to parse proof")) {
    return new VerityError(VerityErrorCode.INVALID_INPUT, msg);
  }
  if (
    msg.includes("Witness map is empty") ||
    msg.includes("Failed to parse witness") ||
    msg.includes("Failed to parse hex")
  ) {
    return new VerityError(VerityErrorCode.WITNESS_READ_ERROR, msg);
  }
  if (msg.includes("Failed to generate proof")) {
    return new VerityError(VerityErrorCode.PROOF_ERROR, msg);
  }
  return new VerityError(VerityErrorCode.PROOF_ERROR, msg);
}

/** Convert a noir_js witness Map to the format ProveKit WASM expects. */
export function convertWitnessMap(witnessMap: Map<unknown, string>): Record<number, string> {
  const result: Record<number, string> = {};
  for (const [witness, value] of witnessMap.entries()) {
    const index =
      typeof witness === "number"
        ? witness
        : typeof (witness as any)?.inner === "number"
          ? (witness as any).inner
          : Number(witness);
    if (Number.isNaN(index)) {
      throw new VerityError(
        VerityErrorCode.WITNESS_READ_ERROR,
        `Failed to extract witness index from key: ${witness}`,
      );
    }
    result[index] = value;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Dispose guard helper
// ---------------------------------------------------------------------------

function assertNotDisposed(disposed: boolean, name: string): void {
  if (disposed) {
    throw new VerityError(VerityErrorCode.RESOURCE_CLOSED, `${name} has been disposed`);
  }
}

// ---------------------------------------------------------------------------
// ProveKit ProverScheme
// ---------------------------------------------------------------------------

class ProveKitProverScheme implements ProverScheme {
  private disposed = false;
  private readonly pkpBytes: Uint8Array;
  private readonly circuitJson: unknown;

  constructor(pkpBytes: Uint8Array, circuitJson: unknown) {
    this.pkpBytes = new Uint8Array(pkpBytes);
    this.circuitJson = circuitJson;
  }

  async prove(inputs: Record<string, unknown> | string): Promise<Proof> {
    assertNotDisposed(this.disposed, "ProverScheme");

    const parsedInputs = typeof inputs === "string" ? JSON.parse(inputs) : inputs;

    // Load noir_js for witness generation
    let Noir: any;
    let decompressWitnessStack: any;
    try {
      const noirJs = await import("@noir-lang/noir_js");
      const acvmJs = await import("@noir-lang/acvm_js");
      Noir = noirJs.Noir;
      decompressWitnessStack = acvmJs.decompressWitnessStack;
    } catch {
      throw new VerityError(
        VerityErrorCode.BACKEND_UNAVAILABLE,
        "ProveKit browser backend requires @noir-lang/noir_js and @noir-lang/acvm_js. Install with: npm install @noir-lang/noir_js @noir-lang/acvm_js",
      );
    }

    // Generate witness via noir_js
    const noir = new Noir(this.circuitJson);
    const { witness: compressedWitness } = await noir.execute(parsedInputs);
    const witnessStack = decompressWitnessStack(compressedWitness);
    const witnessMap: Map<unknown, string> = witnessStack[0].witness;
    const converted = convertWitnessMap(witnessMap);

    // Reconstruct WASM Prover (consumed per call) and prove
    try {
      const prover = new wasmModule.Prover(this.pkpBytes);
      const proofBytes: Uint8Array = prover.proveBytes(converted);
      return Proof.fromBytes(proofBytes);
    } catch (err) {
      throw mapWasmError(err);
    }
  }

  async serialize(): Promise<Uint8Array> {
    assertNotDisposed(this.disposed, "ProverScheme");
    return new Uint8Array(this.pkpBytes);
  }

  dispose(): void {
    this.disposed = true;
  }
}

// ---------------------------------------------------------------------------
// ProveKit VerifierScheme
// ---------------------------------------------------------------------------

class ProveKitVerifierScheme implements VerifierScheme {
  private disposed = false;
  private readonly pkvBytes: Uint8Array;
  private verifier: any;

  constructor(pkvBytes: Uint8Array, verifier: any) {
    this.pkvBytes = new Uint8Array(pkvBytes);
    this.verifier = verifier;
  }

  async verify(proof: Proof): Promise<boolean> {
    assertNotDisposed(this.disposed, "VerifierScheme");
    try {
      this.verifier.verifyBytes(proof.data);
      return true;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes("Verification failed") || msg.includes("proof") || msg.includes("verify")) {
        return false;
      }
      throw mapWasmError(err);
    }
  }

  async serialize(): Promise<Uint8Array> {
    assertNotDisposed(this.disposed, "VerifierScheme");
    return new Uint8Array(this.pkvBytes);
  }

  dispose(): void {
    this.disposed = true;
    this.verifier = null;
  }
}

// ---------------------------------------------------------------------------
// ProveKit Binding
// ---------------------------------------------------------------------------

export class ProveKitBinding implements BackendBinding {
  async init(options?: BackendOptions): Promise<void> {
    if (wasmInitialized) return;

    // Load WASM module
    try {
      wasmModule = await import("../../wasm/provekit_wasm.js");
    } catch {
      throw new VerityError(
        VerityErrorCode.BACKEND_UNAVAILABLE,
        "ProveKit WASM module not found. Ensure WASM artifacts are built (make core-wasm).",
      );
    }

    // Initialize WASM binary
    const wasmUrl = options?.wasmUrl;
    if (wasmUrl) {
      const wasmResponse = await fetch(wasmUrl);
      const wasmBytes = await wasmResponse.arrayBuffer();
      await wasmModule.default(wasmBytes);
    } else {
      await wasmModule.default();
    }

    // Init panic hook
    if (wasmModule.initPanicHook) {
      wasmModule.initPanicHook();
    }

    // Thread pool
    if (options?.threads !== false) {
      const hasSharedArrayBuffer = typeof SharedArrayBuffer !== "undefined";
      const isIOS = typeof navigator !== "undefined" && /iPhone|iPad|iPod/.test(navigator.userAgent);

      if (hasSharedArrayBuffer && !isIOS && wasmModule.initThreadPool) {
        const threadCount = typeof options?.threads === "number"
          ? options.threads
          : (typeof navigator !== "undefined" ? navigator.hardwareConcurrency : 4) || 4;
        try {
          await wasmModule.initThreadPool(threadCount);
        } catch {
          // Fallback to single-threaded — non-fatal
        }
      }
    }

    wasmInitialized = true;
  }

  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    try {
      const tempProver = new wasmModule.Prover(data);
      const circuitBytes: Uint8Array = tempProver.getCircuit();
      const circuitJson = JSON.parse(new TextDecoder().decode(circuitBytes));
      return new ProveKitProverScheme(data, circuitJson);
    } catch (err) {
      throw mapWasmError(err);
    }
  }

  async loadVerifier(data: Uint8Array): Promise<VerifierScheme> {
    try {
      const verifier = new wasmModule.Verifier(data);
      return new ProveKitVerifierScheme(data, verifier);
    } catch (err) {
      throw mapWasmError(err);
    }
  }
}
