import { describe, it, expect } from "vitest";
import { Backend, VerityError, VerityErrorCode } from "../src/index.js";

describe("Verity JS SDK", () => {
  describe("types", () => {
    it("should export Backend enum with correct values", () => {
      expect(Backend.ProveKit).toBe(0);
      expect(Backend.Barretenberg).toBe(1);
    });
  });

  describe("errors", () => {
    it("should create VerityError from code", () => {
      const err = VerityError.fromCode(1, "test detail");
      expect(err).toBeInstanceOf(VerityError);
      expect(err.code).toBe(VerityErrorCode.INVALID_INPUT);
      expect(err.message).toContain("Invalid input");
      expect(err.message).toContain("test detail");
    });

    it("should map OUT_OF_MEMORY to code 10 (matching C FFI)", () => {
      const err = new VerityError(VerityErrorCode.OUT_OF_MEMORY);
      expect(err.code).toBe(10);
      expect(err.message).toContain("Out of memory");
    });

    it("should map BACKEND_UNAVAILABLE to code 11", () => {
      const err = new VerityError(VerityErrorCode.BACKEND_UNAVAILABLE);
      expect(err.code).toBe(11);
      expect(err.message).toContain("Backend not available");
    });

    it("should map RESOURCE_CLOSED to code -2", () => {
      const err = new VerityError(VerityErrorCode.RESOURCE_CLOSED);
      expect(err.code).toBe(-2);
      expect(err.message).toContain("Resource has been disposed");
    });
  });
});
