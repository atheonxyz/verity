import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { defineConfig } from "tsup";

const here = dirname(fileURLToPath(import.meta.url));
const pkg = JSON.parse(readFileSync(resolve(here, "package.json"), "utf8")) as { version: string };
const version = JSON.stringify(pkg.version);

export default defineConfig([
  {
    clean: true,
    entry: { index: "src/browser.ts" },
    format: ["esm"],
    outDir: "dist/browser",
    platform: "browser",
    sourcemap: true,
    splitting: false,
    target: "es2022",
    define: { __VERSION__: version },
    external: [
      "@noir-lang/acvm_js",
      "@noir-lang/noir_js",
      "@noir-lang/noirc_abi",
      "@noir-lang/types",
      "pako",
    ],
  },
  {
    clean: false,
    entry: { index: "src/node.ts" },
    format: ["esm", "cjs"],
    outDir: "dist/node",
    outExtension({ format }) {
      return { js: format === "cjs" ? ".cjs" : ".js" };
    },
    platform: "node",
    sourcemap: true,
    splitting: false,
    target: "node20",
    define: { __VERSION__: version },
    external: [
      "@noir-lang/acvm_js",
      "@noir-lang/noir_js",
      "@noir-lang/noirc_abi",
      "@noir-lang/types",
      "pako",
    ],
  },
]);
