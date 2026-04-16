#!/usr/bin/env node
/**
 * Local dev server with Cross-Origin Isolation headers.
 *
 * Required for SharedArrayBuffer (used by ProveKit WASM thread pool).
 * Serves static files from the example root directory.
 */

import { createServer } from "http";
import { readFile, stat } from "fs/promises";
import { extname, join, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT = resolve(__dirname, "..");
const PORT = parseInt(process.env.PORT || "3000");

const MIME_TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".wasm": "application/wasm",
  ".toml": "text/plain",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

async function handleRequest(req, res) {
  let urlPath = req.url.split("?")[0];
  if (urlPath === "/") urlPath = "/index.html";

  const filePath = join(ROOT, urlPath);

  // Prevent directory traversal
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403, { "Content-Type": "text/plain" });
    res.end("Forbidden");
    return;
  }

  try {
    const stats = await stat(filePath);
    if (stats.isDirectory()) {
      await serveFile(res, join(filePath, "index.html"));
    } else {
      await serveFile(res, filePath);
    }
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not Found");
  }
}

async function serveFile(res, filePath) {
  const data = await readFile(filePath);
  const ext = extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || "application/octet-stream";

  res.writeHead(200, {
    "Content-Type": contentType,
    "Access-Control-Allow-Origin": "*",
    // Cross-Origin Isolation — required for SharedArrayBuffer / WASM threading
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
  });
  res.end(data);
}

const server = createServer(handleRequest);
server.listen(PORT, () => {
  console.log(`\n  Verity Browser Demo`);
  console.log(`  http://localhost:${PORT}`);
  console.log(`\n  Cross-Origin Isolation: ENABLED`);
  console.log(`  SharedArrayBuffer: AVAILABLE`);
  console.log(`\n  Press Ctrl+C to stop.\n`);
});
