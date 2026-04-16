import type { BackendBinding, BackendOptions, ProverScheme, VerifierScheme } from "../types.js";
import { Proof } from "../proof.js";
import { VerityError, VerityErrorCode } from "../errors.js";

// ---------------------------------------------------------------------------
// WASM module singleton
// ---------------------------------------------------------------------------

let wasmModule: any = null;
let wasmInitialized = false;
let wasmInitPromise: Promise<void> | null = null;

type WorkerScopeShim = {
  addEventListener: (...args: unknown[]) => void;
  removeEventListener: (...args: unknown[]) => void;
};

// ---------------------------------------------------------------------------
// Utility functions (exported for testing)
// ---------------------------------------------------------------------------

/** Map a WASM JsError to a typed VerityError. */
export function mapWasmError(err: unknown): VerityError {
  const msg = err instanceof Error ? err.message : String(err);

  if (
    msg.includes("Failed to parse prover") ||
    msg.includes("Failed to parse verifier") ||
    msg.includes("Invalid magic bytes") ||
    msg.includes("Invalid format identifier") ||
    msg.includes("data too short for binary format") ||
    msg.includes("Incompatible prover format") ||
    msg.includes("Incompatible verifier format") ||
    msg.includes("Unknown compression format") ||
    msg.includes("Failed to deserialize prover data") ||
    msg.includes("Failed to deserialize verifier data") ||
    msg.includes("Failed to decompress")
  ) {
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

function parseJsonInputs(inputs: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(inputs) as unknown;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new VerityError(VerityErrorCode.INVALID_INPUT, "JSON input string must decode to an object");
    }
    return parsed as Record<string, unknown>;
  } catch (err) {
    if (err instanceof VerityError) {
      throw err;
    }
    throw new VerityError(VerityErrorCode.INVALID_INPUT, "Failed to parse JSON input string");
  }
}

async function getWasmModuleSpecifiers(isNode: boolean): Promise<string[]> {
  if (isNode && typeof __dirname === "string") {
    const [{ resolve }, { pathToFileURL }] = await Promise.all([
      import("node:path"),
      import("node:url"),
    ]);
    return [
      pathToFileURL(resolve(__dirname, "../wasm/provekit_wasm.js")).href,
      pathToFileURL(resolve(__dirname, "../../wasm/provekit_wasm.js")).href,
    ];
  }

  return [
    new URL("../wasm/provekit_wasm.js", import.meta.url).href,
    new URL("../../wasm/provekit_wasm.js", import.meta.url).href,
  ];
}

async function importFirstAvailable(specifiers: string[]): Promise<any> {
  let lastError: unknown;

  for (const specifier of specifiers) {
    try {
      return await import(specifier);
    } catch (err) {
      lastError = err;
    }
  }

  throw lastError;
}

async function getNodeWasmBinaryPath(): Promise<string> {
  const { access } = await import("node:fs/promises");

  if (typeof __dirname === "string") {
    const { resolve } = await import("node:path");
    const candidates = [
      resolve(__dirname, "../wasm/provekit_wasm_bg.wasm"),
      resolve(__dirname, "../../wasm/provekit_wasm_bg.wasm"),
    ];

    for (const candidate of candidates) {
      try {
        await access(candidate);
        return candidate;
      } catch {
        // Try the next layout.
      }
    }

    return candidates[candidates.length - 1];
  }

  const { fileURLToPath } = await import("node:url");
  const candidates = [
    fileURLToPath(new URL("../wasm/provekit_wasm_bg.wasm", import.meta.url)),
    fileURLToPath(new URL("../../wasm/provekit_wasm_bg.wasm", import.meta.url)),
  ];

  for (const candidate of candidates) {
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Try the next layout.
    }
  }

  return candidates[candidates.length - 1];
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

    const parsedInputs = typeof inputs === "string" ? parseJsonInputs(inputs) : inputs;

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
      const mapped = mapWasmError(err);
      if (mapped.code === VerityErrorCode.INVALID_INPUT) {
        throw mapped;
      }
      return false;
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
    if (!wasmInitPromise) {
      wasmInitPromise = this.initOnce(options).catch((err) => {
        wasmInitPromise = null;
        throw err;
      });
    }
    await wasmInitPromise;
  }

  private async initOnce(options?: BackendOptions): Promise<void> {
    const isNode = typeof process !== "undefined" && !!process.versions?.node;
    const globalScope = globalThis as typeof globalThis & { self?: unknown };
    const hadOwnSelf = Object.prototype.hasOwnProperty.call(globalScope, "self");
    const originalSelf = globalScope.self;
    const wasmModuleSpecifiers = await getWasmModuleSpecifiers(isNode);

    try {
      if (isNode && typeof globalScope.self === "undefined") {
        const workerScopeShim: WorkerScopeShim = {
          addEventListener() {},
          removeEventListener() {},
        };
        Reflect.set(globalScope as object, "self", workerScopeShim);
      }

      wasmModule = await importFirstAvailable(wasmModuleSpecifiers);
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      throw new VerityError(
        VerityErrorCode.BACKEND_UNAVAILABLE,
        `Failed to load ProveKit WASM module. Ensure WASM artifacts are built (make core-wasm). ${detail}`,
      );
    } finally {
      if (isNode) {
        if (hadOwnSelf) {
          Reflect.set(globalScope as object, "self", originalSelf);
        } else {
          Reflect.deleteProperty(globalScope, "self");
        }
      }
    }

    try {
      const wasmUrl = options?.wasmUrl;
      if (wasmUrl) {
        const wasmResponse = await fetch(wasmUrl);
        const wasmBytes = await wasmResponse.arrayBuffer();
        await wasmModule.default({ module_or_path: wasmBytes });
      } else if (isNode) {
        const { readFile } = await import("node:fs/promises");
        const wasmBytes = await readFile(await getNodeWasmBinaryPath());
        await wasmModule.default({ module_or_path: wasmBytes });
      } else {
        await wasmModule.default();
      }
    } catch (err) {
      if (err instanceof VerityError) {
        throw err;
      }
      const detail = err instanceof Error ? err.message : String(err);
      throw new VerityError(
        VerityErrorCode.BACKEND_UNAVAILABLE,
        `Failed to initialize ProveKit WASM runtime. ${detail}`,
      );
    }

    if (wasmModule.initPanicHook) {
      wasmModule.initPanicHook();
    }

    const isBrowser =
      typeof window !== "undefined" &&
      typeof document !== "undefined" &&
      typeof navigator !== "undefined";

    if (isBrowser && options?.threads !== false) {
      const hasSharedArrayBuffer = typeof SharedArrayBuffer !== "undefined";
      const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent);

      if (hasSharedArrayBuffer && !isIOS && wasmModule.initThreadPool) {
        const threadCount =
          typeof options?.threads === "number" ? options.threads : navigator.hardwareConcurrency || 4;
        try {
          await wasmModule.initThreadPool(threadCount);
        } catch {
          // Fallback to single-threaded mode when workers or isolation are unavailable.
        }
      }
    }

    wasmInitialized = true;
  }

  async loadProver(data: Uint8Array): Promise<ProverScheme> {
    const tempProver = new wasmModule.Prover(data);
    try {
      const circuitBytes: Uint8Array = tempProver.getCircuit();
      const circuitJson = JSON.parse(new TextDecoder().decode(circuitBytes));
      return new ProveKitProverScheme(data, circuitJson);
    } catch (err) {
      throw mapWasmError(err);
    } finally {
      tempProver.free();
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
