import { describe, it, expect } from "vitest";
import { Proof } from "../src/proof.js";
import { VerityError, VerityErrorCode } from "../src/errors.js";

describe("Proof", () => {
  const sampleBytes = new Uint8Array([0xde, 0xad, 0xbe, 0xef]);

  it("creates from bytes via fromBytes()", () => {
    const proof = Proof.fromBytes(sampleBytes);
    expect(proof.data).toEqual(sampleBytes);
    expect(proof.size).toBe(4);
  });

  it("makes a defensive copy of input data", () => {
    const input = new Uint8Array([0x01, 0x02]);
    const proof = Proof.fromBytes(input);
    input[0] = 0xff;
    expect(proof.data[0]).toBe(0x01);
  });

  it("computes hex string", () => {
    const proof = Proof.fromBytes(sampleBytes);
    expect(proof.hex).toBe("deadbeef");
  });

  it("returns full hex for small proofs in hexPreview()", () => {
    const proof = Proof.fromBytes(sampleBytes);
    expect(proof.hexPreview()).toBe("deadbeef");
  });

  it("truncates with ... in hexPreview() for large proofs", () => {
    const large = new Uint8Array(64);
    large.fill(0xab);
    const proof = Proof.fromBytes(large);
    const preview = proof.hexPreview(4);
    expect(preview).toBe("abababab...");
  });

  it("returns string representation via toString()", () => {
    const proof = Proof.fromBytes(sampleBytes);
    expect(proof.toString()).toBe("Proof(4 bytes)");
  });

  it("throws INVALID_INPUT on empty bytes", () => {
    expect(() => Proof.fromBytes(new Uint8Array(0))).toThrow(VerityError);
    try {
      Proof.fromBytes(new Uint8Array(0));
    } catch (e) {
      expect((e as VerityError).code).toBe(VerityErrorCode.INVALID_INPUT);
    }
  });
});
