package com.atheon.veritydemo

import android.os.Bundle
import android.os.Debug
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.atheon.verity.Backend
import com.atheon.verity.ProverScheme
import com.atheon.verity.Verity
import com.atheon.verity.VerifierScheme
import com.atheon.veritydemo.databinding.ActivityMainBinding
import com.google.android.material.card.MaterialCardView
import com.google.android.material.snackbar.Snackbar
import java.io.File
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private var selectedCircuitIndex = 0
    private var selectedBackend = Backend.PROVEKIT

    private var lastResult: ProofResult? = null
    @Volatile private var isRunning = false

    // Keep verifier scheme alive for potential re-verification
    @Volatile private var retainedVerifierScheme: VerifierScheme? = null
    @Volatile private var retainedProof: ByteArray? = null

    private val circuitCards: List<MaterialCardView> by lazy {
        listOf(binding.circuitCard0, binding.circuitCard1, binding.circuitCard2)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setSupportActionBar(binding.toolbar)

        setupCircuitCards()
        setupBackendToggle()
        setupGenerateButton()
    }

    override fun onDestroy() {
        super.onDestroy()
        retainedVerifierScheme?.runCatching { close() }
        retainedVerifierScheme = null
    }

    // ── Circuit picker ──────────────────────────────────────────────

    private fun setupCircuitCards() {
        val nameViews = listOf(binding.circuitName0, binding.circuitName1, binding.circuitName2)
        val descViews = listOf(binding.circuitDesc0, binding.circuitDesc1, binding.circuitDesc2)

        BUNDLED_CIRCUITS.forEachIndexed { i, circuit ->
            nameViews[i].text = circuit.name
            descViews[i].text = circuit.description
            circuitCards[i].setOnClickListener { selectCircuit(i) }
        }
        selectCircuit(0)
    }

    private fun selectCircuit(index: Int) {
        selectedCircuitIndex = index
        circuitCards.forEachIndexed { i, card ->
            card.isChecked = (i == index)
        }
    }

    // ── Backend toggle ──────────────────────────────────────────────

    private fun setupBackendToggle() {
        binding.backendToggle.check(binding.btnProveKit.id)

        binding.backendToggle.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (isChecked) {
                selectedBackend = when (checkedId) {
                    binding.btnProveKit.id -> Backend.PROVEKIT
                    binding.btnBarretenberg.id -> Backend.BARRETENBERG
                    else -> Backend.PROVEKIT
                }
            }
        }
    }

    // ── Generate flow ───────────────────────────────────────────────

    private fun setupGenerateButton() {
        binding.btnGenerate.setOnClickListener {
            if (isRunning) return@setOnClickListener
            runFullFlow()
        }
    }

    private fun runFullFlow() {
        val circuit = BUNDLED_CIRCUITS[selectedCircuitIndex]
        val backend = selectedBackend
        val backendLabel = backendDisplayName(backend)

        isRunning = true
        setUiLoading(true)
        binding.resultCard.visibility = View.GONE
        updateStatus(getString(R.string.status_preparing))

        // Release previous scheme
        retainedVerifierScheme?.runCatching { close() }
        retainedVerifierScheme = null
        retainedProof = null
        lastResult = null

        Thread {
            var proverScheme: ProverScheme? = null
            var verifierScheme: VerifierScheme? = null
            try {
                val verity = Verity(backend)

                val inputPath = copyAssetToCache("${circuit.assetDir}/Prover.toml")
                val memBefore = nativeHeapMB()

                // ── Prepare ──
                val prepareMs: Long
                if (backend == Backend.BARRETENBERG) {
                    val circuitPath = copyAssetToCache("${circuit.assetDir}/circuit.json")
                    updateStatus("Compiling ${circuit.name} ($backendLabel)\u2026")
                    val t0 = System.currentTimeMillis()
                    val prepared = verity.prepare(circuit = circuitPath)
                    prepareMs = System.currentTimeMillis() - t0
                    proverScheme = prepared.prover
                    verifierScheme = prepared.verifier
                } else {
                    updateStatus("Loading pre-compiled schemes\u2026")
                    val proverPath = copyAssetToCache("${circuit.assetDir}/prover.pkp")
                    val verifierPath = copyAssetToCache("${circuit.assetDir}/verifier.pkv")
                    proverScheme = verity.loadProver(proverPath)
                    verifierScheme = verity.loadVerifier(verifierPath)
                    prepareMs = 0
                }

                // ── Prove ──
                updateStatus(getString(R.string.status_proving))
                val t1 = System.currentTimeMillis()
                val proof = verity.prove(with = proverScheme, input = inputPath)
                val proveMs = System.currentTimeMillis() - t1

                proverScheme.close()
                proverScheme = null

                // ── Verify ──
                updateStatus(getString(R.string.status_verifying))
                val t2 = System.currentTimeMillis()
                val valid = verity.verify(with = verifierScheme, proof = proof)
                val verifyMs = System.currentTimeMillis() - t2

                val memAfter = nativeHeapMB()

                // Transfer ownership of verifier scheme for potential re-use
                retainedVerifierScheme = verifierScheme
                retainedProof = proof
                verifierScheme = null

                val result = ProofResult(
                    circuit = circuit,
                    backend = backend,
                    proofBytes = proof,
                    prepareTimeMs = prepareMs,
                    proveTimeMs = proveMs,
                    verifyTimeMs = verifyMs,
                    isValid = valid,
                    nativeMemoryMB = memAfter - memBefore,
                )

                runOnUiThread {
                    lastResult = result
                    showResult(result, memAfter)
                    isRunning = false
                    setUiLoading(false)
                }
            } catch (t: Throwable) {
                proverScheme?.runCatching { close() }
                verifierScheme?.runCatching { close() }

                val msg = friendlyError(t, circuit)
                runOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    updateStatus(msg)
                    showError(msg)
                }
            }
        }.apply {
            name = "verity-proof"
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                runOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    val msg = "Unexpected: ${t.message}"
                    updateStatus(msg)
                    showError(msg)
                }
            }
        }.start()
    }

    // ── Result display ──────────────────────────────────────────────

    private fun showResult(result: ProofResult, heapMB: Long) {
        binding.resultCard.visibility = View.VISIBLE

        // Validity chip
        if (result.isValid) {
            binding.validityChip.text = getString(R.string.chip_valid)
            binding.validityChip.setChipBackgroundColorResource(R.color.valid_green)
            binding.validityChip.setTextColor(ContextCompat.getColor(this, R.color.md_on_primary))
        } else {
            binding.validityChip.text = getString(R.string.chip_invalid)
            binding.validityChip.setChipBackgroundColorResource(R.color.invalid_red)
            binding.validityChip.setTextColor(ContextCompat.getColor(this, R.color.md_on_primary))
        }

        // Proof hex
        val hex = result.proofHex
        binding.proofHexText.text = if (hex.length > 160) hex.take(160) + "\u2026" else hex

        // Timing
        val backendLabel = backendDisplayName(result.backend)
        if (result.backend == Backend.BARRETENBERG) {
            binding.prepareTime.text = formatMs(result.prepareTimeMs)
        } else {
            binding.prepareTime.text = "pre-compiled"
        }
        binding.proveTime.text = formatMs(result.proveTimeMs)
        binding.verifyTime.text = formatMs(result.verifyTimeMs)

        // Details
        binding.proofSize.text = formatBytes(result.proofSizeBytes)
        binding.totalTime.text = formatMs(result.totalTimeMs)
        binding.nativeMemory.text = "${heapMB} MB"

        updateStatus("${result.circuit.name} ($backendLabel) \u2014 ${if (result.isValid) "Valid" else "Invalid"}")
    }

    // ── UI helpers ──────────────────────────────────────────────────

    private fun setUiLoading(loading: Boolean) {
        binding.progressBar.visibility = if (loading) View.VISIBLE else View.GONE
        binding.btnGenerate.isEnabled = !loading
        circuitCards.forEach { it.isEnabled = !loading }
        binding.backendToggle.isEnabled = !loading
        for (i in 0 until binding.backendToggle.childCount) {
            binding.backendToggle.getChildAt(i).isEnabled = !loading
        }
    }

    private fun updateStatus(msg: String) {
        runOnUiThread { binding.statusText.text = msg }
    }

    private fun showError(msg: String) {
        Snackbar.make(binding.coordinatorLayout, msg, Snackbar.LENGTH_LONG).show()
    }

    private fun backendDisplayName(b: Backend): String = when (b) {
        Backend.PROVEKIT -> "ProveKit"
        Backend.BARRETENBERG -> "Barretenberg"
    }

    private fun formatMs(ms: Long): String = when {
        ms < 1000 -> "${ms}ms"
        else -> String.format(Locale.US, "%.2fs", ms / 1000.0)
    }

    private fun formatBytes(bytes: Int): String = when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 -> String.format(Locale.US, "%.1f KB", bytes / 1024.0)
        else -> String.format(Locale.US, "%.2f MB", bytes / (1024.0 * 1024.0))
    }

    private fun nativeHeapMB(): Long = Debug.getNativeHeapAllocatedSize() / (1024 * 1024)

    private fun friendlyError(t: Throwable, circuit: Circuit): String = when (t) {
        is UnsatisfiedLinkError ->
            "Native library not found. Ensure libverity_jni.so is built for this device."
        is OutOfMemoryError ->
            "Out of memory running ${circuit.name}. Try a smaller circuit or free device memory."
        is java.io.FileNotFoundException ->
            "Missing asset: ${t.message}"
        else ->
            t.message ?: "Unknown error"
    }

    // ── Asset copy ──────────────────────────────────────────────────

    private fun copyAssetToCache(assetPath: String): String {
        val outFile = File(cacheDir, assetPath.replace("/", "_"))
        if (!outFile.exists()) {
            try {
                assets.open(assetPath).use { input ->
                    outFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: java.io.FileNotFoundException) {
                throw java.io.FileNotFoundException(
                    "Required asset '$assetPath' not found. " +
                    "Ensure circuit files are in app/src/main/assets/."
                )
            }
        }
        return outFile.absolutePath
    }
}
