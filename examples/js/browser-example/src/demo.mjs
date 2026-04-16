/**
 * Verity Browser Demo
 *
 * Demonstrates zero-knowledge proof generation and verification
 * using the Verity SDK with the ProveKit WASM backend.
 */

import { Verity, Backend, Proof } from "@atheon/verity";

// ---------------------------------------------------------------------------
// DOM elements
// ---------------------------------------------------------------------------

const logContainer = document.getElementById("log");
const runBtn = document.getElementById("runBtn");
const statusEl = document.getElementById("status");

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

function log(msg, type = "info") {
  const line = document.createElement("div");
  line.className = `log-${type}`;
  line.textContent = msg;
  logContainer.appendChild(line);
  logContainer.scrollTop = logContainer.scrollHeight;
}

function updateStatus(msg) {
  statusEl.textContent = msg;
}

// ---------------------------------------------------------------------------
// Main demo flow
// ---------------------------------------------------------------------------

let verity = null;

async function init() {
  updateStatus("Initializing ProveKit WASM backend...");
  log("Creating Verity instance with ProveKit backend...");

  try {
    verity = await Verity.create(Backend.ProveKit);
    log("ProveKit WASM initialized", "success");
    updateStatus("Ready");
    runBtn.disabled = false;
  } catch (err) {
    log(`Initialization failed: ${err.message}`, "error");
    updateStatus("Failed to initialize");
  }
}

async function run() {
  runBtn.disabled = true;
  logContainer.innerHTML = "";

  try {
    // --- Load artifacts ---
    updateStatus("Loading artifacts...");
    log("Fetching prover (.pkp) and verifier (.pkv) artifacts...");

    const [pkpResponse, pkvResponse, inputsResponse] = await Promise.all([
      fetch("artifacts/prover.pkp"),
      fetch("artifacts/verifier.pkv"),
      fetch("artifacts/inputs.json"),
    ]);

    if (!pkpResponse.ok || !pkvResponse.ok || !inputsResponse.ok) {
      throw new Error(
        "Missing artifacts. Place prover.pkp, verifier.pkv, and inputs.json in artifacts/."
      );
    }

    const pkpBytes = new Uint8Array(await pkpResponse.arrayBuffer());
    const pkvBytes = new Uint8Array(await pkvResponse.arrayBuffer());
    const inputs = await inputsResponse.json();

    log(`Prover artifact: ${(pkpBytes.byteLength / 1024 / 1024).toFixed(2)} MB`);
    log(`Verifier artifact: ${(pkvBytes.byteLength / 1024 / 1024).toFixed(2)} MB`);
    log(`Inputs: ${Object.keys(inputs).length} top-level keys`);

    // --- Load prover & verifier ---
    updateStatus("Loading prover and verifier...");
    const loadStart = performance.now();
    const prover = await verity.loadProver(pkpBytes);
    const verifier = await verity.loadVerifier(pkvBytes);
    const loadTime = performance.now() - loadStart;
    log(`Load time: ${loadTime.toFixed(0)}ms`);

    // --- Prove ---
    updateStatus("Generating proof...");
    log("Generating proof (this may take a while)...");
    const proveStart = performance.now();
    const proof = await prover.prove(inputs);
    const proveTime = performance.now() - proveStart;
    log(`Proof generated in ${(proveTime / 1000).toFixed(2)}s`, "success");
    log(`Proof size: ${(proof.size / 1024).toFixed(1)} KB`);
    log(`Proof hex (preview): ${proof.hexPreview(32)}`);

    // --- Verify ---
    updateStatus("Verifying proof...");
    log("Verifying proof...");
    const verifyStart = performance.now();
    const isValid = await verifier.verify(proof);
    const verifyTime = performance.now() - verifyStart;

    if (isValid) {
      log(`Proof VALID (${verifyTime.toFixed(0)}ms)`, "success");
    } else {
      log(`Proof INVALID (${verifyTime.toFixed(0)}ms)`, "error");
    }

    // --- Summary ---
    const totalTime = loadTime + proveTime + verifyTime;
    log("");
    log("--- Summary ---");
    log(`Load:   ${loadTime.toFixed(0)}ms`);
    log(`Prove:  ${(proveTime / 1000).toFixed(2)}s`);
    log(`Verify: ${verifyTime.toFixed(0)}ms`);
    log(`Total:  ${(totalTime / 1000).toFixed(2)}s`);
    log(`Proof:  ${(proof.size / 1024).toFixed(1)} KB`);
    log(`Valid:  ${isValid}`);

    updateStatus(isValid ? "Proof verified successfully" : "Proof verification failed");

    // --- Cleanup ---
    prover.dispose();
    verifier.dispose();
  } catch (err) {
    log(`Error: ${err.message}`, "error");
    console.error(err);
    updateStatus("Error");
  } finally {
    runBtn.disabled = false;
  }
}

// ---------------------------------------------------------------------------
// Wire up
// ---------------------------------------------------------------------------

runBtn.addEventListener("click", run);
init();
