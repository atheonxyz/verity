package atheon.verity

import java.util.concurrent.ConcurrentHashMap
import org.json.JSONObject

/**
 * Verity — generate and verify zero-knowledge proofs on Android.
 *
 * Usage:
 * ```kotlin
 * val verity = Verity(Backend.PROVEKIT)
 * val scheme = verity.prepare(circuit = "circuit.json")
 * val proof  = verity.prove(with = scheme.prover, input = "Prover.toml")
 * val valid  = verity.verify(with = scheme.verifier, proof = proof)
 * scheme.close()
 * ```
 */
class Verity(private val backend: Backend) {

    init {
        ensureInitialized(backend)
    }

    /**
     * Compile a circuit into prover + verifier schemes (no files written).
     *
     * @param circuit Path to compiled circuit (ACIR JSON from `nargo compile`).
     * @return A [PreparedScheme] containing both prover and verifier handles.
     */
    fun prepare(circuit: String): PreparedScheme {
        require(circuit.isNotEmpty()) { "circuit path cannot be empty" }
        val handles = nativePrepare(backend.ordinal, circuit)
        val prover = ProverScheme(handles[0])
        val verifier: VerifierScheme
        try {
            verifier = VerifierScheme(handles[1])
        } catch (t: Throwable) {
            prover.close()
            throw t
        }
        return PreparedScheme(prover = prover, verifier = verifier)
    }

    /**
     * Generate a proof using a TOML input file.
     *
     * @param with Prover scheme from [prepare] or [loadProver].
     * @param input Path to input file (.toml).
     * @return Proof bytes.
     */
    fun prove(with: ProverScheme, input: String): ByteArray {
        with.ensureOpen()
        require(input.isNotEmpty()) { "input path cannot be empty" }
        val proof = nativeProveToml(with.handle, input)
        if (proof.isEmpty()) {
            throw VerityException.ProofFailed("empty proof returned")
        }
        return proof
    }

    /**
     * Generate a proof using a map of inputs.
     *
     * Values are serialized to JSON and parsed by the circuit's ABI.
     * Field elements should be strings (e.g., `"5"` or `"0x1a2b..."`).
     *
     * @param with Prover scheme from [prepare] or [loadProver].
     * @param inputs Map of parameter names to values.
     * @return Proof bytes.
     */
    fun prove(with: ProverScheme, inputs: Map<String, Any>): ByteArray {
        with.ensureOpen()
        require(inputs.isNotEmpty()) { "inputs map cannot be empty" }
        val jsonObj = JSONObject(inputs)
        val json = jsonObj.toString()
        require(json.length > 2) { "inputs could not be serialized to valid JSON" }
        val proof = nativeProveJson(with.handle, json)
        if (proof.isEmpty()) {
            throw VerityException.ProofFailed("empty proof returned")
        }
        return proof
    }

    /**
     * Verify a proof.
     *
     * @param with Verifier scheme from [prepare] or [loadVerifier].
     * @param proof Proof bytes (from [prove]).
     * @return `true` if the proof is valid.
     */
    fun verify(with: VerifierScheme, proof: ByteArray): Boolean {
        with.ensureOpen()
        require(proof.isNotEmpty()) { "proof cannot be empty" }
        val code = nativeVerify(with.handle, proof)
        return when (code) {
            0 -> true
            4 -> false
            else -> throw VerityException.fromCode(code)
        }
    }

    // -- Load from file --

    /**
     * Load a prover scheme from a file.
     *
     * @param path Path to saved prover file.
     * @return A [ProverScheme] handle.
     */
    fun loadProver(path: String): ProverScheme {
        require(path.isNotEmpty()) { "path cannot be empty" }
        return ProverScheme(nativeLoadProver(backend.ordinal, path))
    }

    /**
     * Load a verifier scheme from a file.
     *
     * @param path Path to saved verifier file.
     * @return A [VerifierScheme] handle.
     */
    fun loadVerifier(path: String): VerifierScheme {
        require(path.isNotEmpty()) { "path cannot be empty" }
        return VerifierScheme(nativeLoadVerifier(backend.ordinal, path))
    }

    // -- Load from bytes --

    /**
     * Load a prover scheme from bytes.
     *
     * Accepts the same format as saved files — useful for data downloaded
     * from a URL or bundled in an app.
     *
     * @param data Serialized prover bytes.
     * @return A [ProverScheme] handle.
     */
    fun loadProver(data: ByteArray): ProverScheme {
        require(data.isNotEmpty()) { "data cannot be empty" }
        return ProverScheme(nativeLoadProverBytes(backend.ordinal, data))
    }

    /**
     * Load a verifier scheme from bytes.
     *
     * Accepts the same format as saved files — useful for data downloaded
     * from a URL or bundled in an app.
     *
     * @param data Serialized verifier bytes.
     * @return A [VerifierScheme] handle.
     */
    fun loadVerifier(data: ByteArray): VerifierScheme {
        require(data.isNotEmpty()) { "data cannot be empty" }
        return VerifierScheme(nativeLoadVerifierBytes(backend.ordinal, data))
    }

    /**
     * Data class holding ProveKit memory usage statistics.
     *
     * @property ramUsed Current RAM usage in bytes.
     * @property swapUsed Current swap (file-backed) usage in bytes.
     * @property peakRam Peak RAM usage in bytes since initialization.
     */
    data class MemoryStats(
        val ramUsed: Long,
        val swapUsed: Long,
        val peakRam: Long,
    )

    companion object {

        /**
         * Configure the ProveKit memory allocator.
         *
         * **Must be called before creating any [Verity] instance** (i.e., before
         * `verity_init` is called). Has no effect on the Barretenberg backend.
         *
         * @param ramLimitBytes Maximum RAM the prover may use before spilling
         *                      to disk. Pass 0 for no limit.
         * @param useFileBacked If `true`, allocations beyond the RAM limit are
         *                      backed by a memory-mapped file (swap-to-disk).
         * @param swapFilePath  Path for the swap file. Required when
         *                      [useFileBacked] is `true`; ignored otherwise.
         */
        @JvmStatic
        fun configureMemory(
            ramLimitBytes: Long,
            useFileBacked: Boolean = false,
            swapFilePath: String? = null,
        ) {
            loadLibrary()
            val code = nativeConfigureMemory(ramLimitBytes, useFileBacked, swapFilePath)
            if (code != 0) throw VerityException.fromCode(code)
        }

        /**
         * Query current ProveKit memory usage.
         *
         * @return A [MemoryStats] snapshot. Only meaningful for the ProveKit backend.
         */
        @JvmStatic
        fun getMemoryStats(): MemoryStats {
            loadLibrary()
            val stats = nativeGetMemoryStats()
            return MemoryStats(
                ramUsed = stats[0],
                swapUsed = stats[1],
                peakRam = stats[2],
            )
        }
        @Volatile
        private var libraryLoaded = false
        private val initializedBackends: MutableSet<Int> = ConcurrentHashMap.newKeySet()

        private fun loadLibrary() {
            if (!libraryLoaded) {
                synchronized(Companion) {
                    if (!libraryLoaded) {
                        System.loadLibrary("verity_jni")
                        libraryLoaded = true
                    }
                }
            }
        }

        private fun ensureInitialized(backend: Backend) {
            loadLibrary()
            if (backend.ordinal !in initializedBackends) {
                synchronized(Companion) {
                    if (backend.ordinal !in initializedBackends) {
                        val code = nativeInit(backend.ordinal)
                        if (code != 0) {
                            throw VerityException.FfiError(code)
                        }
                        initializedBackends.add(backend.ordinal)
                    }
                }
            }
        }

        @JvmStatic
        private external fun nativeInit(backend: Int): Int

        @JvmStatic
        private external fun nativePrepare(backend: Int, circuitPath: String): LongArray

        @JvmStatic
        private external fun nativeProveToml(proverHandle: Long, inputPath: String): ByteArray

        @JvmStatic
        private external fun nativeProveJson(proverHandle: Long, inputsJson: String): ByteArray

        @JvmStatic
        private external fun nativeVerify(verifierHandle: Long, proof: ByteArray): Int

        @JvmStatic
        private external fun nativeLoadProver(backend: Int, path: String): Long

        @JvmStatic
        private external fun nativeLoadVerifier(backend: Int, path: String): Long

        @JvmStatic
        private external fun nativeLoadProverBytes(backend: Int, data: ByteArray): Long

        @JvmStatic
        private external fun nativeLoadVerifierBytes(backend: Int, data: ByteArray): Long

        @JvmStatic
        internal fun saveProver(handle: Long, path: String): Int = nativeSaveProver(handle, path)
        @JvmStatic
        internal fun saveVerifier(handle: Long, path: String): Int = nativeSaveVerifier(handle, path)
        @JvmStatic
        internal fun serializeProver(handle: Long): ByteArray = nativeSerializeProver(handle)
        @JvmStatic
        internal fun serializeVerifier(handle: Long): ByteArray = nativeSerializeVerifier(handle)
        @JvmStatic
        internal fun freeProver(handle: Long) = nativeFreeProver(handle)
        @JvmStatic
        internal fun freeVerifier(handle: Long) = nativeFreeVerifier(handle)

        @JvmStatic
        private external fun nativeSaveProver(proverHandle: Long, path: String): Int

        @JvmStatic
        private external fun nativeSaveVerifier(verifierHandle: Long, path: String): Int

        @JvmStatic
        private external fun nativeSerializeProver(proverHandle: Long): ByteArray

        @JvmStatic
        private external fun nativeSerializeVerifier(verifierHandle: Long): ByteArray

        @JvmStatic
        private external fun nativeFreeProver(proverHandle: Long)

        @JvmStatic
        private external fun nativeFreeVerifier(verifierHandle: Long)

        @JvmStatic
        private external fun nativeConfigureMemory(
            ramLimitBytes: Long, useFileBacked: Boolean, swapFilePath: String?): Int

        @JvmStatic
        private external fun nativeGetMemoryStats(): LongArray
    }
}
