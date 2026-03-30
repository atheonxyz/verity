package com.atheon.verity

import java.io.File

/**
 * A compiled circuit (ACIR JSON from `nargo compile`).
 *
 * Load a circuit first, then pass it to [Verity.prepare].
 *
 * ```kotlin
 * val circuit = Circuit.load(File(context.cacheDir, "circuit.json"))
 * val circuit = Circuit.load("/path/to/circuit.json")
 * val scheme  = verity.prepare(circuit)
 * ```
 */
class Circuit private constructor(
    private val rawData: ByteArray?,
    /** Original file path, if loaded from a file. */
    private val sourcePath: String?
) {

    /** The raw circuit JSON data. Loaded lazily if the circuit was opened from a file path. */
    val data: ByteArray by lazy {
        rawData ?: try {
            File(sourcePath ?: error("Circuit has no data source")).readBytes()
        } catch (e: Exception) {
            throw VerityException.SchemeReadError(e)
        }
    }

    /**
     * Resolve to a file path for the FFI layer.
     * If loaded from a file, returns the original path.
     * If created from bytes, writes to a temp file.
     *
     * @return Pair of (path, isTemporary). Caller must delete temp files.
     */
    internal fun resolvePath(): Pair<String, Boolean> {
        if (sourcePath != null) return Pair(sourcePath, false)

        val tmp = File.createTempFile("verity_circuit_", ".json")
        try {
            tmp.writeBytes(rawData ?: error("Circuit has no data to write"))
        } catch (e: Exception) {
            tmp.delete()
            throw e
        }
        return Pair(tmp.absolutePath, true)
    }

    companion object {
        /**
         * Load a circuit from a [File].
         *
         * @param file The compiled circuit JSON file.
         * @throws VerityException.SchemeReadError if the file cannot be read.
         */
        @JvmStatic
        fun load(file: File): Circuit {
            if (!file.exists() || !file.canRead()) {
                throw VerityException.SchemeReadError()
            }
            return Circuit(null, file.absolutePath)
        }

        /**
         * Load a circuit from a file path string.
         *
         * @param path Path to compiled circuit JSON file.
         * @throws VerityException.SchemeReadError if the file cannot be read.
         */
        @JvmStatic
        fun load(path: String): Circuit = load(File(path))

        /**
         * Create a circuit from raw JSON bytes.
         *
         * @param data ACIR JSON bytes (from `nargo compile`).
         */
        @JvmStatic
        fun fromBytes(data: ByteArray): Circuit {
            require(data.isNotEmpty()) { "circuit data cannot be empty" }
            return Circuit(data.copyOf(), null)
        }
    }
}
