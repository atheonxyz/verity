package xyz.atheon.veritydemo

import android.os.Bundle
import android.os.Debug
import android.view.View
import android.widget.ArrayAdapter
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import xyz.atheon.verity.Backend
import xyz.atheon.verity.Proof
import xyz.atheon.verity.ProverScheme
import xyz.atheon.verity.Verity
import xyz.atheon.verity.VerifierScheme
import xyz.atheon.verity.VerityException
import xyz.atheon.verity.Witness
import xyz.atheon.veritydemo.databinding.ActivityMainBinding
import com.google.android.material.snackbar.Snackbar
import java.io.File
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private val backends = listOf(Backend.PROVEKIT, Backend.BARRETENBERG)

    private var selectedCircuit: DemoCircuit = BUNDLED_CIRCUITS[0]
    private var selectedBackend: Backend = backends[0]
    private var usePrecompiled: Boolean = true

    @Volatile private var isRunning = false
    @Volatile private var isDestroyed = false
    private var activeThread: Thread? = null

    // Retained for re-verify (single circuit)
    @Volatile private var lastResult: ProofResult? = null
    @Volatile private var lastProof: Proof? = null
    @Volatile private var lastVerifierScheme: VerifierScheme? = null

    // Retained for re-verify (fragmented)
    @Volatile private var lastFragmentedProofs: List<Proof>? = null
    @Volatile private var lastFragmentedVerifiers: List<VerifierScheme>? = null
    @Volatile private var lastFragmentedCircuit: DemoCircuit? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isDestroyed = false
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setSupportActionBar(binding.toolbar)

        setupCircuitSelector()
        setupBackendSelector()
        binding.precompiledSwitch.setOnCheckedChangeListener { _, checked ->
            usePrecompiled = checked
            clearState()
        }

        binding.generateButton.setOnClickListener {
            if (isRunning) return@setOnClickListener
            if (selectedCircuit.isFragmented) runFragmented() else runGenerateAndVerify()
        }
        binding.reverifyButton.setOnClickListener {
            if (isRunning) return@setOnClickListener
            // Use the circuit that generated the proofs, not the currently selected one
            if (lastFragmentedProofs != null) runReverifyFragmented()
            else if (lastProof != null) runReverify()
        }
    }

    override fun onDestroy() {
        isDestroyed = true
        activeThread?.interrupt()
        activeThread = null
        closeRetainedSchemes()
        super.onDestroy()
    }

    private fun closeRetainedSchemes() {
        lastVerifierScheme?.runCatching { close() }
        lastVerifierScheme = null
        lastFragmentedVerifiers?.forEach { it.runCatching { close() } }
        lastFragmentedVerifiers = null
    }

    /** Post to UI thread only if the activity is still alive. */
    private fun safeRunOnUiThread(block: () -> Unit) {
        if (!isDestroyed) runOnUiThread(block)
    }

    // -- Selectors --

    private fun setupCircuitSelector() {
        val adapter = ArrayAdapter(this, android.R.layout.simple_dropdown_item_1line, BUNDLED_CIRCUITS)
        binding.circuitSelector.setAdapter(adapter)
        binding.circuitSelector.setText(BUNDLED_CIRCUITS[0].toString(), false)
        binding.circuitSelector.setOnItemClickListener { _, _, position, _ ->
            selectedCircuit = BUNDLED_CIRCUITS[position]
            clearState()
        }
    }

    private fun setupBackendSelector() {
        val names = listOf("ProveKit (WHIR)", "Barretenberg (UltraHonk)")
        val adapter = ArrayAdapter(this, android.R.layout.simple_dropdown_item_1line, names)
        binding.backendSelector.setAdapter(adapter)
        binding.backendSelector.setText(names[0], false)
        binding.backendSelector.setOnItemClickListener { _, _, position, _ ->
            selectedBackend = backends[position]
            clearState()
        }
    }

    private fun clearState() {
        lastResult = null
        lastProof = null
        lastFragmentedProofs = null
        lastFragmentedCircuit = null
        closeRetainedSchemes()
        binding.reverifyButton.isEnabled = false
        binding.proofCard.visibility = View.GONE
        binding.statsCard.visibility = View.GONE
        binding.validityChip.visibility = View.GONE
        binding.statusText.text = getString(R.string.status_ready)
    }

    // -- Generate & Verify (single circuit) --

    private fun runGenerateAndVerify() {
        val circuit = selectedCircuit
        val backend = selectedBackend
        val bName = backendDisplayName(backend)

        isRunning = true
        setUiLoading(true)
        clearState()
        updateStatus("Initializing...")

        val thread = Thread {
            var proverScheme: ProverScheme? = null
            var verifierScheme: VerifierScheme? = null
            try {
                val verity = Verity(backend)

                val inputPath = copyAssetToCache("${circuit.assetDir}/Prover.toml")
                val memBefore = nativeHeapMB()

                // -- Prepare or Load --
                val prepareStart = System.nanoTime()
                var prover: ProverScheme
                var verifier: VerifierScheme
                var usedPrecompiled = false

                if (usePrecompiled && backend == Backend.PROVEKIT) {
                    updateStatus("Loading precompiled ${circuit.name} ($bName)...")
                    try {
                        val proverPath = copyAssetToCache("${circuit.assetDir}/prover.pkp")
                        val verifierPath = copyAssetToCache("${circuit.assetDir}/verifier.pkv")
                        prover = verity.loadProver(proverPath)
                        verifier = verity.loadVerifier(verifierPath)
                        usedPrecompiled = true
                    } catch (e: Exception) {
                        android.util.Log.w("VerityDemo", "Precompiled load failed, falling back to prepare", e)
                        updateStatus("Preparing ${circuit.name} ($bName)...")
                        val circuitPath = copyAssetToCache("${circuit.assetDir}/circuit.json")
                        val prepared = verity.prepare(circuitPath)
                        prover = prepared.prover
                        verifier = prepared.verifier
                    }
                } else {
                    updateStatus("Preparing ${circuit.name} ($bName)...")
                    val circuitPath = copyAssetToCache("${circuit.assetDir}/circuit.json")
                    val prepared = verity.prepare(circuitPath)
                    prover = prepared.prover
                    verifier = prepared.verifier
                }
                val prepareMs = (System.nanoTime() - prepareStart) / 1_000_000
                proverScheme = prover
                verifierScheme = verifier

                // -- Prove --
                updateStatus("Generating proof ($bName)...")
                val witness = Witness.load(inputPath)
                val proveStart = System.nanoTime()
                val proof = proverScheme.prove(witness)
                val proveMs = (System.nanoTime() - proveStart) / 1_000_000

                proverScheme.close()
                proverScheme = null

                // -- Verify --
                updateStatus("Verifying proof...")
                val verifyStart = System.nanoTime()
                val isValid = verifierScheme.verify(proof)
                val verifyMs = (System.nanoTime() - verifyStart) / 1_000_000

                val memAfter = nativeHeapMB()

                // Retain for re-verify
                lastProof = proof
                lastVerifierScheme = verifierScheme
                verifierScheme = null

                val result = ProofResult(
                    circuit = circuit, backend = backend, proof = proof,
                    prepareTimeMs = prepareMs, proveTimeMs = proveMs,
                    verifyTimeMs = verifyMs, isValid = isValid,
                    nativeMemoryMB = memAfter - memBefore,
                    usedPrecompiled = usedPrecompiled,
                )
                lastResult = result

                safeRunOnUiThread {
                    showResult(result, memAfter)
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                proverScheme?.runCatching { close() }
                verifierScheme?.runCatching { close() }
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    updateStatus("Error: $msg")
                    showError(msg)
                }
            }
        }.apply {
            name = "verity-generate"
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    updateStatus("Error: $msg")
                    showError(msg)
                }
            }
        }
        activeThread = thread
        thread.start()
    }

    // -- Re-verify (single circuit) --

    private fun runReverify() {
        val proof = lastProof ?: return
        val verifierScheme = lastVerifierScheme ?: return
        val prevResult = lastResult ?: return

        isRunning = true
        setUiLoading(true)
        binding.proofCard.visibility = View.GONE
        binding.statsCard.visibility = View.GONE
        binding.validityChip.visibility = View.GONE
        updateStatus("Re-verifying proof...")

        val thread = Thread {
            try {
                val verifyStart = System.nanoTime()
                val isValid = verifierScheme.verify(proof)
                val verifyMs = (System.nanoTime() - verifyStart) / 1_000_000

                val result = prevResult.copy(verifyTimeMs = verifyMs, isValid = isValid)
                lastResult = result

                safeRunOnUiThread {
                    showResult(result, nativeHeapMB())
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                val msg = friendlyError(t, prevResult.circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                    showResult(prevResult, nativeHeapMB())
                    updateStatus("Re-verify error: $msg")
                    showError(msg)
                }
            }
        }.apply {
            name = "verity-reverify"
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                val msg = friendlyError(t, prevResult.circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                    showResult(prevResult, nativeHeapMB())
                    updateStatus("Re-verify error: $msg")
                    showError(msg)
                }
            }
        }
        activeThread = thread
        thread.start()
    }

    // -- Generate & Verify (fragmented) --

    private fun runFragmented() {
        val circuit = selectedCircuit
        val backend = selectedBackend
        val bName = backendDisplayName(backend)
        val steps = circuit.steps ?: return

        isRunning = true
        setUiLoading(true)
        clearState()
        updateStatus("Initializing...")

        val thread = Thread {
            val verifiers = mutableListOf<VerifierScheme>()
            try {
                val verity = Verity(backend)
                val proofs = mutableListOf<Proof>()
                val memBefore = nativeHeapMB()

                data class StepTiming(
                    val step: String, val prepareMs: Long,
                    val proveMs: Long, val verifyMs: Long,
                    val isValid: Boolean,
                )
                val timings = mutableListOf<StepTiming>()

                for ((index, step) in steps.withIndex()) {
                    updateStatus("Step ${index + 1}/${steps.size}: $step ($bName)...")

                    val inputPath = copyAssetToCache("${circuit.assetDir}/$step/Prover.toml")
                    val proverPath = copyAssetToCache("${circuit.assetDir}/$step/prover.pkp")
                    val verifierPath = copyAssetToCache("${circuit.assetDir}/$step/verifier.pkv")

                    // Prepare
                    val prepareStart = System.nanoTime()
                    val proverScheme = verity.loadProver(proverPath)
                    val verifierScheme = verity.loadVerifier(verifierPath)
                    val prepareMs = (System.nanoTime() - prepareStart) / 1_000_000
                    verifiers.add(verifierScheme)

                    // Prove
                    val witness = Witness.load(inputPath)
                    val proveStart = System.nanoTime()
                    val proof = proverScheme.prove(witness)
                    val proveMs = (System.nanoTime() - proveStart) / 1_000_000
                    proverScheme.close()
                    proofs.add(proof)

                    // Verify
                    updateStatus("Verifying step ${index + 1}/${steps.size}...")
                    val verifyStart = System.nanoTime()
                    val isValid = verifierScheme.verify(proof)
                    val verifyMs = (System.nanoTime() - verifyStart) / 1_000_000

                    timings.add(StepTiming(step, prepareMs, proveMs, verifyMs, isValid))

                    if (!isValid) break
                }

                val memAfter = nativeHeapMB()
                val allValid = timings.all { it.isValid }
                val totalPrepareMs = timings.sumOf { it.prepareMs }
                val totalProveMs = timings.sumOf { it.proveMs }
                val totalVerifyMs = timings.sumOf { it.verifyMs }
                val totalProofBytes = proofs.sumOf { it.size }

                // Retain for re-verify
                lastFragmentedVerifiers?.forEach { it.runCatching { close() } }
                lastFragmentedProofs = proofs
                lastFragmentedVerifiers = verifiers.toList()
                lastFragmentedCircuit = circuit

                val combinedHex = proofs.joinToString("") { it.hex }

                val stats = buildString {
                    append("Circuit:  ${circuit.name}\n")
                    append("Backend:  $bName\n")
                    append("\n")
                    for (t in timings) {
                        append("${t.step}\n")
                        append("  Prepare: ${formatMs(t.prepareMs)}  ")
                        append("Prove: ${formatMs(t.proveMs)}  ")
                        append("Verify: ${formatMs(t.verifyMs)}  ")
                        append(if (t.isValid) "VALID" else "INVALID")
                        append("\n")
                    }
                    append("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n")
                    append("Prepare:  ${formatMs(totalPrepareMs)}\n")
                    append("Prove:    ${formatMs(totalProveMs)}\n")
                    append("Verify:   ${formatMs(totalVerifyMs)}\n")
                    append("Total:    ${formatMs(totalPrepareMs + totalProveMs + totalVerifyMs)}\n")
                    append("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n")
                    append("Proof:    ${formatBytes(totalProofBytes)} (${proofs.size} proofs)\n")
                    append("Memory:   ${memBefore}MB \u2192 ${memAfter}MB")
                }

                safeRunOnUiThread {
                    binding.proofCard.visibility = View.VISIBLE
                    binding.proofLabel.text = "Proof chain (${formatBytes(totalProofBytes)}, ${proofs.size} steps)"
                    binding.proofHexText.text = if (combinedHex.length > 160) combinedHex.take(160) + "\u2026" else combinedHex
                    updateValidityChip(allValid)
                    binding.statsCard.visibility = View.VISIBLE
                    binding.statsText.text = stats
                    updateStatus(
                        if (allValid) "${circuit.name}: All ${steps.size} proofs valid"
                        else "${circuit.name}: Proof chain invalid"
                    )
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                verifiers.forEach { it.runCatching { close() } }
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    updateStatus("Error: $msg")
                    showError(msg)
                }
            }
        }.apply {
            name = "verity-generate-fragmented"
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    updateStatus("Error: $msg")
                    showError(msg)
                }
            }
        }
        activeThread = thread
        thread.start()
    }

    // -- Re-verify (fragmented) --

    private fun runReverifyFragmented() {
        val proofs = lastFragmentedProofs ?: return
        val verifiers = lastFragmentedVerifiers ?: return
        val circuit = lastFragmentedCircuit ?: return
        val steps = circuit.steps ?: return

        isRunning = true
        setUiLoading(true)
        binding.proofCard.visibility = View.GONE
        binding.statsCard.visibility = View.GONE
        binding.validityChip.visibility = View.GONE
        updateStatus("Re-verifying ${proofs.size} proofs...")

        val thread = Thread {
            try {
                val timings = mutableListOf<Pair<String, Long>>()
                var allValid = true

                for (i in proofs.indices) {
                    updateStatus("Re-verifying step ${i + 1}/${proofs.size}: ${steps[i]}...")
                    val t0 = System.nanoTime()
                    val valid = verifiers[i].verify(proofs[i])
                    val ms = (System.nanoTime() - t0) / 1_000_000
                    timings.add(steps[i] to ms)
                    if (!valid) {
                        allValid = false
                        break
                    }
                }

                val totalVerifyMs = timings.sumOf { it.second }
                val totalProofBytes = proofs.sumOf { it.size }
                val combinedHex = proofs.joinToString("") { it.hex }

                val stats = buildString {
                    append("Re-verify: ${circuit.name}\n")
                    append("\n")
                    for ((step, ms) in timings) {
                        append("  $step: ${formatMs(ms)}\n")
                    }
                    append("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n")
                    append("Total verify: ${formatMs(totalVerifyMs)}")
                }
                val statusMsg = if (allValid) "All ${proofs.size} proofs VALID" else "Proof chain INVALID"

                safeRunOnUiThread {
                    binding.proofCard.visibility = View.VISIBLE
                    binding.proofLabel.text = "Proof chain (${formatBytes(totalProofBytes)}, ${proofs.size} steps)"
                    binding.proofHexText.text = if (combinedHex.length > 160) combinedHex.take(160) + "\u2026" else combinedHex
                    binding.statsCard.visibility = View.VISIBLE
                    binding.statsText.text = stats
                    updateValidityChip(allValid)
                    updateStatus(statusMsg)
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                    updateStatus("Re-verify error: $msg")
                    showError(msg)
                }
            }
        }.apply {
            name = "verity-reverify-fragmented"
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                val msg = friendlyError(t, circuit)
                safeRunOnUiThread {
                    isRunning = false
                    setUiLoading(false)
                    binding.reverifyButton.isEnabled = true
                    updateStatus("Re-verify error: $msg")
                    showError(msg)
                }
            }
        }
        activeThread = thread
        thread.start()
    }

    // -- Result display --

    private fun showResult(result: ProofResult, heapMB: Long) {
        val bName = backendDisplayName(result.backend)

        binding.proofCard.visibility = View.VISIBLE
        binding.proofLabel.text = "Proof (${formatBytes(result.proofSize)})"
        binding.proofHexText.text = result.proof.hexPreview(80)
        updateValidityChip(result.isValid)

        val stats = buildString {
            append("Circuit:  ${result.circuit.name}\n")
            append("Backend:  $bName\n")
            append("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n")
            val prepLabel = if (result.usedPrecompiled) "Load" else "Prepare"
            append("$prepLabel:  ${formatMs(result.prepareTimeMs)}\n")
            append("Prove:    ${formatMs(result.proveTimeMs)}\n")
            append("Verify:   ${formatMs(result.verifyTimeMs)}\n")
            append("Total:    ${formatMs(result.totalTimeMs)}\n")
            append("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n")
            append("Proof:    ${formatBytes(result.proofSize)}\n")
            append("Memory:   ${heapMB}MB")
        }
        binding.statsCard.visibility = View.VISIBLE
        binding.statsText.text = stats

        val statusSuffix = if (result.isValid) "Valid" else "Invalid"
        updateStatus("${result.circuit.name} ($bName) \u2014 $statusSuffix")
    }

    private fun updateValidityChip(valid: Boolean) {
        binding.validityChip.visibility = View.VISIBLE
        if (valid) {
            binding.validityChip.text = getString(R.string.chip_valid)
            binding.validityChip.setChipBackgroundColorResource(R.color.valid_green)
            binding.validityChip.setTextColor(ContextCompat.getColor(this, R.color.md_on_primary))
        } else {
            binding.validityChip.text = getString(R.string.chip_invalid)
            binding.validityChip.setChipBackgroundColorResource(R.color.invalid_red)
            binding.validityChip.setTextColor(ContextCompat.getColor(this, R.color.md_on_primary))
        }
    }

    // -- UI helpers --

    private fun setUiLoading(loading: Boolean) {
        binding.progressBar.visibility = if (loading) View.VISIBLE else View.GONE
        binding.generateButton.isEnabled = !loading
        binding.circuitSelector.isEnabled = !loading
        binding.backendSelector.isEnabled = !loading
    }

    private fun updateStatus(msg: String) {
        safeRunOnUiThread { binding.statusText.text = msg }
    }

    private fun showError(msg: String) {
        if (!isDestroyed) {
            Snackbar.make(binding.coordinatorLayout, msg, Snackbar.LENGTH_LONG).show()
        }
    }

    private fun backendDisplayName(b: Backend): String = when (b) {
        Backend.PROVEKIT -> "ProveKit"
        Backend.BARRETENBERG -> "Barretenberg"
    }

    private fun formatMs(ms: Long): String = when {
        ms < 1 -> "<1ms"
        ms < 1000 -> "${ms}ms"
        else -> String.format(Locale.US, "%.2fs", ms / 1000.0)
    }

    private fun formatBytes(bytes: Int): String = when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 -> String.format(Locale.US, "%.1f KB", bytes / 1024.0)
        else -> String.format(Locale.US, "%.2f MB", bytes / (1024.0 * 1024.0))
    }

    private fun nativeHeapMB(): Long = Debug.getNativeHeapAllocatedSize() / (1024 * 1024)

    private fun friendlyError(t: Throwable, circuit: DemoCircuit): String = when (t) {
        is UnsatisfiedLinkError ->
            "Native library not found. Ensure libverity_jni.so is built for this device."
        is OutOfMemoryError ->
            "Out of memory running ${circuit.name}. Try a smaller circuit or free device memory."
        is java.io.FileNotFoundException ->
            "Missing asset: ${t.message}"
        is VerityException.CompilationFailed ->
            "Circuit compilation failed for ${circuit.name}. Check that circuit.json is valid."
        is VerityException.SchemeReadError ->
            "Failed to read scheme file for ${circuit.name}. Check that .pkp/.pkv files are valid."
        is VerityException ->
            t.message ?: "Verity error"
        else ->
            t.message ?: "Unknown error"
    }

    // -- Asset copy --

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
