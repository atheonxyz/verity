import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
import { Backend, Proof, Verity } from "../src/index.js";

const fixturesDir = new URL("./fixtures/", import.meta.url);
const requiredFiles = [
  new URL("./fixtures/prover.pkp", import.meta.url),
  new URL("./fixtures/verifier.pkv", import.meta.url),
  new URL("./fixtures/inputs.json", import.meta.url),
  new URL("../wasm/provekit_wasm.js", import.meta.url),
];
const describeIfReady = requiredFiles.every((file) => existsSync(file)) ? describe : describe.skip;

describeIfReady("ProveKit integration", () => {
  it("loads artifacts, proves, verifies, and supports reuse", async () => {
    const [pkpBytes, pkvBytes, inputs] = await Promise.all([
      readFile(new URL("./prover.pkp", fixturesDir)),
      readFile(new URL("./verifier.pkv", fixturesDir)),
      readFile(new URL("./inputs.json", fixturesDir), "utf8").then(JSON.parse),
    ]);

    const verity = await Verity.create(Backend.ProveKit, { threads: false });
    const prover = await verity.loadProver(new Uint8Array(pkpBytes));
    const verifier = await verity.loadVerifier(new Uint8Array(pkvBytes));

    const proof = await prover.prove(inputs);
    expect(proof).toBeInstanceOf(Proof);
    expect(proof.size).toBeGreaterThan(0);
    expect(await verifier.verify(proof)).toBe(true);

    const proof2 = await prover.prove(inputs);
    expect(await verifier.verify(proof2)).toBe(true);

    const tamperedPayload = JSON.parse(new TextDecoder().decode(proof.data)) as {
      whir_r1cs_proof: { narg_string: string };
    };
    const proofString = tamperedPayload.whir_r1cs_proof.narg_string;
    tamperedPayload.whir_r1cs_proof.narg_string =
      (proofString[0] === "A" ? "B" : "A") + proofString.slice(1);
    const tampered = Proof.fromBytes(new TextEncoder().encode(JSON.stringify(tamperedPayload)));
    expect(await verifier.verify(tampered)).toBe(false);

    expect(await prover.serialize()).toEqual(new Uint8Array(pkpBytes));
    expect(await verifier.serialize()).toEqual(new Uint8Array(pkvBytes));

    prover.dispose();
    verifier.dispose();
  });
});
