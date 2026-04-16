import { cp, mkdir, rm, stat } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const sdkRoot = resolve(here, "..");
const srcDir = resolve(sdkRoot, "wasm");
const distDir = resolve(sdkRoot, "dist", "wasm");

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

if (!(await exists(resolve(srcDir, "provekit_wasm.js")))) {
  throw new Error(
    "Missing sdks/js/wasm artifacts. Run `make core-wasm` before building the JS SDK.",
  );
}

await mkdir(resolve(sdkRoot, "dist"), { recursive: true });
await cp(srcDir, distDir, { recursive: true, force: true });
await rm(resolve(distDir, ".gitignore"), { force: true });
