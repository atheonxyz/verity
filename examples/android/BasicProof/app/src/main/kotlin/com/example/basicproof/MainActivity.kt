package com.example.basicproof

import android.os.Bundle
import android.os.Debug
import android.view.View
import android.widget.ArrayAdapter
import androidx.appcompat.app.AppCompatActivity
import com.aspect.verity.Backend
import com.aspect.verity.Verity
import com.aspect.verity.VerifierScheme
import com.example.basicproof.databinding.ActivityMainBinding
import java.io.File

data class Circuit(
    val name: String,
    val assetDir: String,
) {
    override fun toString() = name
}

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private val circuits = listOf(
        Circuit("Poseidon2", "circuits/poseidon2"),
        Circuit("SHA-256", "circuits/noir_sha256"),
        Circuit("Passport Age Check", "circuits/complete_age_check"),
    )

    private val backends = listOf(Backend.PROVEKIT, Backend.BARRETENBERG)

    private var selectedCircuit: Circuit = circuits[0]
    private var selectedBackend: Backend = backends[0]

    // Stored after proof generation so verify can use them
    @Volatile private var lastProof: ByteArray? = null
    @Volatile private var lastVerifierScheme: VerifierScheme? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Circuit dropdown
        val circuitAdapter = ArrayAdapter(this, android.R.layout.simple_dropdown_item_1line, circuits)
        binding.circuitSelector.setAdapter(circuitAdapter)
        binding.circuitSelector.setText(circuits[0].toString(), false)
        binding.circuitSelector.setOnItemClickListener { _, _, position, _ ->
            selectedCircuit = circuits[position]
            clearProof()
        }

        // Backend dropdown
        val backendNames = listOf("ProveKit (WHIR)", "Barretenberg (UltraHonk)")
        val backendAdapter = ArrayAdapter(this, android.R.layout.simple_dropdown_item_1line, backendNames)
        binding.backendSelector.setAdapter(backendAdapter)
        binding.backendSelector.setText(backendNames[0], false)
        binding.backendSelector.setOnItemClickListener { _, _, position, _ ->
            selectedBackend = backends[position]
            clearProof()
        }

        binding.proveButton.setOnClickListener { runProve() }
        binding.verifyButton.setOnClickListener { runVerify() }
    }

    override fun onDestroy() {
        super.onDestroy()
        lastVerifierScheme?.close()
        lastVerifierScheme = null
    }

    private fun clearProof() {
        lastProof = null
        lastVerifierScheme?.close()
        lastVerifierScheme = null
        binding.verifyButton.isEnabled = false
        binding.proofCard.visibility = View.GONE
        binding.statsCard.visibility = View.GONE
        binding.statusText.text = "Ready"
    }

    private fun backendName(b: Backend) = if (b == Backend.PROVEKIT) "ProveKit" else "Barretenberg"

    private fun nativeMemoryMB(): Long {
        return Debug.getNativeHeapAllocatedSize() / (1024 * 1024)
    }

    private fun runProve() {
        val circuit = selectedCircuit
        val backend = selectedBackend
        val bName = backendName(backend)

        binding.proveButton.isEnabled = false
        binding.verifyButton.isEnabled = false
        binding.statusText.text = "Initializing..."
        binding.proofCard.visibility = View.GONE
        binding.statsCard.visibility = View.GONE

        Thread {
            var proverScheme: com.aspect.verity.ProverScheme? = null
            var verifierScheme: VerifierScheme? = null
            try {
                val verity = Verity(backend)

                updateStatus("Setting up ${circuit.name} ($bName)...")
                val inputPath = copyAssetToCache("${circuit.assetDir}/Prover.toml")
                val memBefore = nativeMemoryMB()

                var prepareMs: Long
                val proof: ByteArray

                if (backend == Backend.BARRETENBERG) {
                    val circuitPath = copyAssetToCache("${circuit.assetDir}/circuit.json")

                    updateStatus("Preparing circuit ($bName)...")
                    val prepareStart = System.currentTimeMillis()
                    val prepared = verity.prepare(circuit = circuitPath)
                    prepareMs = System.currentTimeMillis() - prepareStart
                    proverScheme = prepared.prover
                    verifierScheme = prepared.verifier
                } else {
                    // ProveKit: load pre-compiled schemes from asset files
                    val proverPath = copyAssetToCache("${circuit.assetDir}/prover.pkp")
                    val verifierPath = copyAssetToCache("${circuit.assetDir}/verifier.pkv")
                    proverScheme = verity.loadProver(proverPath)
                    verifierScheme = verity.loadVerifier(verifierPath)
                    prepareMs = 0
                }

                updateStatus("Generating proof ($bName)...")
                val proveStart = System.currentTimeMillis()
                proof = verity.prove(with = proverScheme, input = inputPath)
                val proveMs = System.currentTimeMillis() - proveStart
                val memAfterProve = nativeMemoryMB()

                proverScheme.close()
                proverScheme = null

                // Store for verify — close previous scheme and transfer ownership
                lastVerifierScheme?.close()
                lastProof = proof
                lastVerifierScheme = verifierScheme
                verifierScheme = null  // ownership transferred, don't close in finally

                val hex = proof.joinToString("") { "%02x".format(it) }

                val stats = buildString {
                    append("Circuit:  ${circuit.name}\n")
                    append("Backend:  $bName\n")
                    if (backend == Backend.BARRETENBERG) {
                        append("Prepare:  ${prepareMs}ms\n")
                    } else {
                        append("Prepare:  pre-compiled (.pkp)\n")
                    }
                    append("Prove:    ${proveMs}ms\n")
                    append("─────────────────\n")
                    append("Native heap: ${memBefore}MB → ${memAfterProve}MB\n")
                    append("Proof size:  ${proof.size} bytes")
                }

                runOnUiThread {
                    binding.proofCard.visibility = View.VISIBLE
                    binding.proofLabel.text = "Proof (${proof.size} bytes)"
                    binding.proofText.text = hex.take(120) + "..."
                    binding.statsCard.visibility = View.VISIBLE
                    binding.statsText.text = stats
                    binding.statusText.text = "${circuit.name}: Proof generated"
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                proverScheme?.runCatching { close() }
                verifierScheme?.runCatching { close() }
                val errorMsg = when (t) {
                    is UnsatisfiedLinkError ->
                        "Native library not found. Ensure libverity_jni.so is built for this device's architecture."
                    is OutOfMemoryError ->
                        "Out of memory while running ${circuit.name}. Try a smaller circuit or free up device memory."
                    is java.io.FileNotFoundException ->
                        "Missing asset file: ${t.message}. Ensure circuit assets are bundled in the app."
                    else ->
                        t.message ?: "Unknown error"
                }
                runOnUiThread {
                    binding.statusText.text = "Error: $errorMsg"
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = false
                }
            }
        }.apply {
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                runOnUiThread {
                    binding.statusText.text = "Unexpected error: ${t.message}"
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = false
                }
            }
        }.start()
    }

    private fun runVerify() {
        val proof = lastProof ?: return
        val verifierScheme = lastVerifierScheme ?: return

        binding.proveButton.isEnabled = false
        binding.verifyButton.isEnabled = false
        binding.statusText.text = "Verifying proof..."

        Thread {
            try {
                val verifyStart = System.currentTimeMillis()
                val valid = Verity(selectedBackend).verify(with = verifierScheme, proof = proof)
                val verifyMs = System.currentTimeMillis() - verifyStart

                val verifyStats = "\nVerify:   ${verifyMs}ms"
                val statusMsg = if (valid) "Proof VALID" else "Proof INVALID"

                runOnUiThread {
                    binding.statsText.append(verifyStats)
                    binding.statusText.text = statusMsg
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = true
                }
            } catch (t: Throwable) {
                val errorMsg = when (t) {
                    is UnsatisfiedLinkError ->
                        "Native library not found."
                    is OutOfMemoryError ->
                        "Out of memory during verification."
                    else ->
                        t.message ?: "Unknown error"
                }
                runOnUiThread {
                    binding.statusText.text = "Verify error: $errorMsg"
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = true
                }
            }
        }.apply {
            uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, t ->
                runOnUiThread {
                    binding.statusText.text = "Verify error: ${t.message}"
                    binding.proveButton.isEnabled = true
                    binding.verifyButton.isEnabled = true
                }
            }
        }.start()
    }

    private fun updateStatus(msg: String) {
        runOnUiThread { binding.statusText.text = msg }
    }

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
                    "Ensure circuit files are present in app/src/main/assets/."
                )
            }
        }
        return outFile.absolutePath
    }

}
