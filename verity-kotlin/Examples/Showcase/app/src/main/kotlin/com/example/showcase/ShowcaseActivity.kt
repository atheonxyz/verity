package com.example.showcase

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import atheon.verity.Backend
import atheon.verity.Verity
import com.example.showcase.databinding.ActivityShowcaseBinding
import java.io.File

/**
 * Demonstrates every Verity SDK capability:
 *
 * [1] Load pre-compiled schemes (.pkp/.pkv)
 * [2] Prove with TOML file input
 * [3] Verify proof
 * [4] Scheme reuse (prove + verify again with same handles)
 * [5] Save → Load round-trip (file persistence)
 * [6] Serialize → Load bytes round-trip (in-memory persistence)
 *
 * No prepare() step — uses pre-compiled scheme files from assets.
 */
class ShowcaseActivity : AppCompatActivity() {

    private lateinit var binding: ActivityShowcaseBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityShowcaseBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.provekitButton.setOnClickListener { run(Backend.PROVEKIT) }
        binding.barretenbergButton.setOnClickListener { run(Backend.BARRETENBERG) }
        binding.bothButton.setOnClickListener { runBoth() }
    }

    private fun run(backend: Backend) {
        setButtonsEnabled(false)
        clearLog()

        val inputPath = copyAssetToCache("Prover.toml")

        Thread {
            val name = backendName(backend)
            append("=== $name Backend ===\n")

            try {
                val verity = Verity(backend)

                // ── 1. Load pre-compiled schemes ──
                append("[1] Loading pre-compiled schemes...")
                val proverPath = copyAssetToCache("prover.pkp")
                val verifierPath = copyAssetToCache("verifier.pkv")
                val prover = verity.loadProver(proverPath)
                val verifier = verity.loadVerifier(verifierPath)
                append("    Prover + Verifier handles loaded from .pkp/.pkv\n")

                // ── 2. Prove with TOML file ──
                append("[2] Proving with TOML file...")
                val proof = verity.prove(with = prover, input = inputPath)
                append("    Proof: ${proof.size} bytes\n")

                // ── 3. Verify ──
                append("[3] Verifying...")
                val valid = verity.verify(with = verifier, proof = proof)
                append("    Result: ${if (valid) "VALID" else "INVALID"}\n")

                // ── 4. Prove again (scheme reuse) ──
                append("[4] Proving again (same scheme, reuse test)...")
                val proof2 = verity.prove(with = prover, input = inputPath)
                val valid2 = verity.verify(with = verifier, proof = proof2)
                append("    Second proof: ${proof2.size} bytes, valid: $valid2\n")

                // ── 5. Save → Load round-trip ──
                append("[5] Save -> Load round-trip...")
                val tmpDir = File(cacheDir, "showcase_$name")
                tmpDir.mkdirs()

                val ext = if (backend == Backend.PROVEKIT) "pk" else "bb"
                val savedProverPath = File(tmpDir, "prover.${ext}p").absolutePath
                val savedVerifierPath = File(tmpDir, "verifier.${ext}v").absolutePath

                prover.save(savedProverPath)
                verifier.save(savedVerifierPath)
                append("    Saved to ${tmpDir.absolutePath}")

                val loadedProver = verity.loadProver(savedProverPath)
                val loadedVerifier = verity.loadVerifier(savedVerifierPath)

                val proof3 = verity.prove(with = loadedProver, input = inputPath)
                val valid3 = verity.verify(with = loadedVerifier, proof = proof3)
                append("    Load -> Prove -> Verify: ${if (valid3) "VALID" else "INVALID"}\n")

                loadedProver.close()
                loadedVerifier.close()
                tmpDir.deleteRecursively()

                // ── 6. Serialize → Load bytes round-trip ──
                append("[6] Serialize -> Load bytes round-trip...")
                val proverBytes = prover.serialize()
                val verifierBytes = verifier.serialize()
                append("    Prover: ${proverBytes.size} bytes, Verifier: ${verifierBytes.size} bytes")

                val restoredProver = verity.loadProver(proverBytes)
                val restoredVerifier = verity.loadVerifier(verifierBytes)

                val proof4 = verity.prove(with = restoredProver, input = inputPath)
                val valid4 = verity.verify(with = restoredVerifier, proof = proof4)
                append("    Bytes -> Load -> Prove -> Verify: ${if (valid4) "VALID" else "INVALID"}\n")

                restoredProver.close()
                restoredVerifier.close()

                // Clean up original handles
                prover.close()
                verifier.close()

                append("=== $name DONE ===")
            } catch (e: Exception) {
                append("ERROR: ${e.message}")
            }

            runOnUiThread { setButtonsEnabled(true) }
        }.start()
    }

    private fun runBoth() {
        setButtonsEnabled(false)
        clearLog()

        val inputPath = copyAssetToCache("Prover.toml")

        Thread {
            for (backend in listOf(Backend.PROVEKIT, Backend.BARRETENBERG)) {
                val name = backendName(backend)
                append("=== $name ===")

                try {
                    val verity = Verity(backend)

                    val prover = verity.loadProver(copyAssetToCache("prover.pkp"))
                    val verifier = verity.loadVerifier(copyAssetToCache("verifier.pkv"))

                    val proof = verity.prove(with = prover, input = inputPath)
                    val valid = verity.verify(with = verifier, proof = proof)
                    append("  Proof: ${proof.size} bytes -> ${if (valid) "VALID" else "INVALID"}\n")

                    prover.close()
                    verifier.close()
                } catch (e: Exception) {
                    append("  ERROR: ${e.message}\n")
                }
            }

            append("=== Comparison complete ===")
            runOnUiThread { setButtonsEnabled(true) }
        }.start()
    }

    private fun setButtonsEnabled(enabled: Boolean) {
        binding.provekitButton.isEnabled = enabled
        binding.barretenbergButton.isEnabled = enabled
        binding.bothButton.isEnabled = enabled
    }

    private fun clearLog() {
        binding.logText.text = ""
    }

    private fun append(msg: String) {
        runOnUiThread {
            binding.logText.append("$msg\n")
            binding.logScroll.post {
                binding.logScroll.fullScroll(android.view.View.FOCUS_DOWN)
            }
        }
    }

    private fun backendName(b: Backend) = if (b == Backend.PROVEKIT) "ProveKit" else "Barretenberg"

    private fun copyAssetToCache(assetPath: String): String {
        val outFile = File(cacheDir, assetPath.replace("/", "_"))
        if (!outFile.exists()) {
            assets.open(assetPath).use { input ->
                outFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        }
        return outFile.absolutePath
    }
}
