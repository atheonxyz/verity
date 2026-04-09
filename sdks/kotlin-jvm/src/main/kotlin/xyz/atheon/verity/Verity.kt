package xyz.atheon.verity

import java.util.concurrent.ConcurrentHashMap

/**
 * Verity — generate and verify zero-knowledge proofs on JVM.
 *
 * `Verity` is a factory for creating prover and verifier schemes.
 * Use the schemes directly to generate and verify proofs.
 *
 * ```kotlin
 * val verity   = Verity(Backend.PROVEKIT)
 * val prover   = verity.loadProver("prover.pkp")
 * val verifier = verity.loadVerifier("verifier.pkv")
 * val witness  = Witness.load("Prover.toml")
 * val proof    = prover.prove(witness)
 * val valid    = verifier.verify(proof)
 * ```
 */

/** ProveKit memory usage statistics. */
data class MemoryStats(
    /** Current RAM usage in bytes. */
    val ramUsed: Long,
    /** Current swap file usage in bytes. */
    val swapUsed: Long,
    /** Peak RAM usage in bytes. */
    val peakRam: Long,
)

class Verity(private val backend: Backend) {

    init {
        ensureInitialized(backend)
    }

    // -- Load from file --

    /**
     * Load a prover scheme from a file.
     *
     * @param path Path to saved prover file.
     * @return A [ProverScheme] handle.
     */
    @Throws(VerityException::class)
    fun loadProver(path: String): ProverScheme {
        require(path.isNotEmpty()) { "path cannot be empty" }
        return ProverScheme(nativeLoadProver(backend.code, path))
    }

    /**
     * Load a verifier scheme from a file.
     *
     * @param path Path to saved verifier file.
     * @return A [VerifierScheme] handle.
     */
    @Throws(VerityException::class)
    fun loadVerifier(path: String): VerifierScheme {
        require(path.isNotEmpty()) { "path cannot be empty" }
        return VerifierScheme(nativeLoadVerifier(backend.code, path))
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
    @Throws(VerityException::class)
    fun loadProver(data: ByteArray): ProverScheme {
        require(data.isNotEmpty()) { "data cannot be empty" }
        return ProverScheme(nativeLoadProverBytes(backend.code, data))
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
    @Throws(VerityException::class)
    fun loadVerifier(data: ByteArray): VerifierScheme {
        require(data.isNotEmpty()) { "data cannot be empty" }
        return VerifierScheme(nativeLoadVerifierBytes(backend.code, data))
    }

    companion object {
        /** The SDK version string (e.g., `"0.2.0"`). */
        const val VERSION = "0.3.3"

        /**
         * Configure the ProveKit memory allocator.
         *
         * Call before creating a [Verity] instance to limit RAM usage and enable
         * file-backed memory for large circuits on memory-constrained devices.
         *
         * Only applies to the ProveKit backend.
         *
         * @param ramLimitBytes Maximum RAM for the prover in bytes (0 = unlimited).
         * @param useFileBacked If true, spill allocations to a swap file.
         * @param swapFilePath Path to swap file (required if useFileBacked is true).
         */
        @JvmStatic
        @JvmOverloads
        @Throws(VerityException::class)
        fun configureMemory(
            ramLimitBytes: Long = 0,
            useFileBacked: Boolean = false,
            swapFilePath: String? = null,
        ) {
            require(ramLimitBytes >= 0) { "ramLimitBytes must be non-negative" }
            if (useFileBacked) {
                require(!swapFilePath.isNullOrEmpty()) { "swapFilePath is required when useFileBacked is true" }
            }
            loadLibrary()
            val code = nativeConfigureMemory(ramLimitBytes, useFileBacked, swapFilePath)
            if (code != 0) throw VerityException.fromCode(code)
        }

        /**
         * Get current ProveKit memory usage statistics.
         *
         * Only applies to the ProveKit backend.
         *
         * @return A [MemoryStats] with current usage.
         */
        @JvmStatic
        @Throws(VerityException::class)
        fun memoryStats(): MemoryStats {
            loadLibrary()
            return nativeGetMemoryStats()
        }

        @Volatile
        private var libraryLoaded = false
        private val initializedBackends: MutableSet<Int> = ConcurrentHashMap.newKeySet()

        private fun loadLibrary() {
            if (!libraryLoaded) {
                synchronized(Companion) {
                    if (!libraryLoaded) {
                        NativeLoader.load()
                        val tmpDir = System.getProperty("java.io.tmpdir") ?: "/tmp"
                        nativeConfigureHome(tmpDir)
                        libraryLoaded = true
                    }
                }
            }
        }

        private fun ensureInitialized(backend: Backend) {
            loadLibrary()
            if (backend.code !in initializedBackends) {
                synchronized(Companion) {
                    if (backend.code !in initializedBackends) {
                        val code = nativeInit(backend.code)
                        if (code != 0) {
                            throw VerityException.fromCode(code)
                        }
                        initializedBackends.add(backend.code)
                    }
                }
            }
        }

        @JvmStatic
        private external fun nativeConfigureHome(homeDir: String)

        @JvmStatic
        private external fun nativeInit(backend: Int): Int

        @JvmStatic
        private external fun nativeProveToml(proverHandle: Long, inputPath: String): ByteArray

        @JvmStatic
        private external fun nativeProveJson(proverHandle: Long, inputsJson: String): ByteArray

        @JvmStatic
        private external fun nativeVerify(verifierHandle: Long, proof: ByteArray): Int

        @JvmStatic
        internal fun proveToml(handle: Long, inputPath: String): ByteArray = nativeProveToml(handle, inputPath)
        @JvmStatic
        internal fun proveJson(handle: Long, inputsJson: String): ByteArray = nativeProveJson(handle, inputsJson)
        @JvmStatic
        internal fun verify(handle: Long, proof: ByteArray): Int = nativeVerify(handle, proof)

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
        private external fun nativeConfigureMemory(ramLimitBytes: Long, useFileBacked: Boolean, swapFilePath: String?): Int

        @JvmStatic
        private external fun nativeGetMemoryStats(): MemoryStats
    }
}
