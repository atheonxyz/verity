import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const sdkRoot = resolve(here, "..");
const fixturesDir = resolve(sdkRoot, "tests", "fixtures");

async function loadFixtures() {
  const [pkpBytes, pkvBytes, inputs] = await Promise.all([
    readFile(resolve(fixturesDir, "prover.pkp")),
    readFile(resolve(fixturesDir, "verifier.pkv")),
    readFile(resolve(fixturesDir, "inputs.json"), "utf8").then(JSON.parse),
  ]);

  return {
    pkpBytes: new Uint8Array(pkpBytes),
    pkvBytes: new Uint8Array(pkvBytes),
    inputs,
  };
}

async function smokeRuntime(label, runtime) {
  const { pkpBytes, pkvBytes, inputs } = await loadFixtures();
  const verity = await runtime.Verity.create(runtime.Backend.ProveKit, { threads: false });
  const prover = await verity.loadProver(pkpBytes);
  const verifier = await verity.loadVerifier(pkvBytes);

  try {
    const proof = await prover.prove(inputs);
    const valid = await verifier.verify(proof);

    if (!valid) {
      throw new Error(`${label}: expected proof verification to succeed`);
    }

    console.log(`${label}: prove/verify ok (${proof.size} bytes)`);
  } finally {
    prover.dispose();
    verifier.dispose();
  }
}

const esmRuntime = await import(pathToFileURL(resolve(sdkRoot, "dist", "node", "index.js")).href);
await smokeRuntime("node-esm", esmRuntime);

const require = createRequire(import.meta.url);
const cjsRuntime = require(resolve(sdkRoot, "dist", "node", "index.cjs"));
await smokeRuntime("node-cjs", cjsRuntime);
