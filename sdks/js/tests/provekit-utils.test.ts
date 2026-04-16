import { describe, it, expect } from "vitest";
import { mapWasmError, convertWitnessMap } from "../src/backends/provekit.js";
import { VerityError, VerityErrorCode } from "../src/errors.js";

describe("mapWasmError", () => {
  it("maps prover parse errors to SCHEME_READ_ERROR", () => {
    const err = mapWasmError(new Error("Failed to parse prover JSON: invalid"));
    expect(err).toBeInstanceOf(VerityError);
    expect(err.code).toBe(VerityErrorCode.SCHEME_READ_ERROR);
  });

  it("maps verifier parse errors to SCHEME_READ_ERROR", () => {
    const err = mapWasmError(new Error("Failed to parse verifier JSON: bad data"));
    expect(err.code).toBe(VerityErrorCode.SCHEME_READ_ERROR);
  });

  it("maps binary format errors to SCHEME_READ_ERROR", () => {
    const err = mapWasmError(new Error("Invalid magic bytes in prover data"));
    expect(err.code).toBe(VerityErrorCode.SCHEME_READ_ERROR);
  });

  it("maps decompression errors to SCHEME_READ_ERROR", () => {
    const err = mapWasmError(new Error("Failed to decompress XZ data: invalid header"));
    expect(err.code).toBe(VerityErrorCode.SCHEME_READ_ERROR);
  });

  it("maps proof generation errors to PROOF_ERROR", () => {
    const err = mapWasmError(new Error("Failed to generate proof: timeout"));
    expect(err.code).toBe(VerityErrorCode.PROOF_ERROR);
  });

  it("maps proof parse errors to INVALID_INPUT", () => {
    const err = mapWasmError(new Error("Failed to parse proof JSON: malformed"));
    expect(err.code).toBe(VerityErrorCode.INVALID_INPUT);
  });

  it("maps empty witness errors to WITNESS_READ_ERROR", () => {
    const err = mapWasmError(new Error("Witness map is empty"));
    expect(err.code).toBe(VerityErrorCode.WITNESS_READ_ERROR);
  });

  it("maps hex parse errors to WITNESS_READ_ERROR", () => {
    const err = mapWasmError(new Error("Failed to parse hex string at index 3: invalid"));
    expect(err.code).toBe(VerityErrorCode.WITNESS_READ_ERROR);
  });

  it("maps unknown errors to PROOF_ERROR", () => {
    const err = mapWasmError(new Error("Something unexpected"));
    expect(err.code).toBe(VerityErrorCode.PROOF_ERROR);
  });

  it("preserves original error message in detail", () => {
    const err = mapWasmError(new Error("Failed to parse prover JSON: bad"));
    expect(err.message).toContain("Failed to parse prover JSON: bad");
  });
});

describe("convertWitnessMap", () => {
  it("converts Map with numeric keys", () => {
    const map = new Map<unknown, string>([[0, "0x01"], [1, "0xff"]]);
    const result = convertWitnessMap(map);
    expect(result).toEqual({ 0: "0x01", 1: "0xff" });
  });

  it("converts Map with string-numeric keys", () => {
    const map = new Map<unknown, string>([["0", "0x01"], ["5", "0xff"]]);
    const result = convertWitnessMap(map);
    expect(result).toEqual({ 0: "0x01", 5: "0xff" });
  });

  it("converts Map with Witness objects (inner property)", () => {
    const map = new Map<unknown, string>([
      [{ inner: 0 }, "0x01"],
      [{ inner: 3 }, "0xab"],
    ]);
    const result = convertWitnessMap(map);
    expect(result).toEqual({ 0: "0x01", 3: "0xab" });
  });

  it("throws WITNESS_READ_ERROR on non-numeric keys", () => {
    const map = new Map<unknown, string>([[{}, "0x01"]]);
    expect(() => convertWitnessMap(map)).toThrow(VerityError);
    try {
      convertWitnessMap(map);
    } catch (e) {
      expect((e as VerityError).code).toBe(VerityErrorCode.WITNESS_READ_ERROR);
      expect((e as VerityError).message).toContain("Failed to extract witness index");
    }
  });
});
