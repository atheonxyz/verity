#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import { chromium } from "playwright";

const PORT = process.env.PORT || "3000";
const ORIGIN = `http://127.0.0.1:${PORT}`;

async function waitForServer(url, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // Server not ready yet.
    }
    await delay(250);
  }
  throw new Error(`Server did not start within ${timeoutMs}ms`);
}

const server = spawn(process.execPath, ["scripts/serve.mjs"], {
  cwd: new URL("..", import.meta.url),
  env: { ...process.env, PORT },
  stdio: ["ignore", "pipe", "pipe"],
});

const serverLogs = [];
server.stdout.on("data", (chunk) => {
  const text = chunk.toString();
  serverLogs.push(text);
  process.stdout.write(text);
});
server.stderr.on("data", (chunk) => {
  const text = chunk.toString();
  serverLogs.push(text);
  process.stderr.write(text);
});

try {
  await waitForServer(ORIGIN);

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const errors = [];

  page.on("pageerror", (error) => errors.push(error));
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push(new Error(message.text()));
    }
  });

  await page.goto(ORIGIN, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => document.getElementById("status")?.textContent?.trim() === "Ready",
    undefined,
    { timeout: 120000 },
  );

  await page.click("#runBtn");

  await page.waitForFunction(
    () => {
      const status = document.getElementById("status")?.textContent?.trim() || "";
      return status === "Proof verified successfully" || status === "Error";
    },
    undefined,
    { timeout: 240000 },
  );

  const status = await page.locator("#status").innerText();
  const logText = await page.locator("#log").innerText();

  assert.match(status, /Proof verified successfully/);
  assert.match(logText, /Proof VALID/);
  assert.equal(errors.length, 0, errors.map((error) => error.stack || error.message).join("\n\n"));

  await browser.close();
} finally {
  server.kill("SIGTERM");
}
