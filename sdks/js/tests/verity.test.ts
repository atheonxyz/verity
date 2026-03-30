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

    it("should create VerityError for backend unavailable", () => {
      const err = new VerityError(VerityErrorCode.BACKEND_UNAVAILABLE);
      expect(err.code).toBe(VerityErrorCode.BACKEND_UNAVAILABLE);
      expect(err.message).toContain("Backend not available");
    });
  });
});
