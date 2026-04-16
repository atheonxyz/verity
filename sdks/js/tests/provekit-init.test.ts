import { describe, expect, it, vi } from "vitest";
import { VerityErrorCode } from "../src/errors.js";

describe("ProveKitBinding init", () => {
  it("allows retry after a failed initialization attempt", async () => {
    vi.resetModules();

    const { ProveKitBinding } = await import("../src/backends/provekit.js");
    const binding = new ProveKitBinding();

    await expect(
      binding.init({ wasmUrl: "http://127.0.0.1:1/missing.wasm" }),
    ).rejects.toMatchObject({ code: VerityErrorCode.BACKEND_UNAVAILABLE });

    await expect(binding.init({ threads: false })).resolves.toBeUndefined();
  });
});
