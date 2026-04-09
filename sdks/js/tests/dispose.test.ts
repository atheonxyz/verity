import { describe, it, expect } from "vitest";
import { VerityError, VerityErrorCode } from "../src/errors.js";

describe("dispose guards", () => {
  it("RESOURCE_CLOSED error has correct code and message", () => {
    const err = new VerityError(VerityErrorCode.RESOURCE_CLOSED, "ProverScheme has been disposed");
    expect(err.code).toBe(VerityErrorCode.RESOURCE_CLOSED);
    expect(err.message).toContain("Resource has been disposed");
    expect(err.message).toContain("ProverScheme has been disposed");
  });

  it("RESOURCE_CLOSED code is -2", () => {
    expect(VerityErrorCode.RESOURCE_CLOSED).toBe(-2);
  });
});
