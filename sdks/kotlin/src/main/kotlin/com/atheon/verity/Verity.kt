package com.atheon.verity

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
        return PreparedScheme(
            prover = ProverScheme(handles[0]),
            verifier = VerifierScheme(handles[1]),
        )
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
        return nativeProveToml(with.handle, input)
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
        val json = JSONObject(inputs).toString()
        return nativeProveJson(with.handle, json)
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
            4, 5 -> false  // PROOF_ERROR or SERIALIZATION_ERROR = invalid proof
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

    companion object {
        @Volatile
        private var libraryLoaded = false
        private val initializedBackends: MutableSet<Int> = ConcurrentHashMap.newKeySet()

        private fun loadLibrary() {
            if (!libraryLoaded) {
                synchronized(Companion) {
                    if (!libraryLoaded) {
                        System.loadLibrary("verity_jni")
                        // Set HOME for backends that need writable dirs (e.g., Barretenberg SRS).
                        val tmpDir = System.getProperty("java.io.tmpdir") ?: "/data/local/tmp"
                        nativeConfigureHome(tmpDir)
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
        private external fun nativeConfigureHome(homeDir: String)

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
    }
}
