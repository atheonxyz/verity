declare module "../../wasm/provekit_wasm.js" {
  export class Prover {
    constructor(proverData: Uint8Array);
    proveBytes(witnessMap: unknown): Uint8Array;
    getCircuit(): Uint8Array;
  }

  export class Verifier {
    constructor(verifierData: Uint8Array);
    verifyBytes(proofData: Uint8Array): void;
  }

  export function initPanicHook(): void;
  export function initThreadPool(numThreads: number): Promise<void>;

  export default function init(input?: BufferSource | WebAssembly.Module): Promise<unknown>;
}
