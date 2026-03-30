package com.aspect.verity

/**
 * Opaque handle to a compiled prover scheme.
 *
 * Created by [Verity.prepare] or [Verity.loadProver].
 * Can be reused for multiple prove calls from any thread.
 * Must be [close]d when no longer needed (or use [use]).
 * Do not call [close] while another thread is using this scheme.
 */
class ProverScheme internal constructor(internal val handle: Long) : AutoCloseable {

    @Volatile
    private var closed = false

    internal fun ensureOpen() {
        check(!closed) { "ProverScheme is closed" }
    }

    /**
     * Save the prover scheme to a file.
     *
     * @param path Destination file path.
     */
    fun save(path: String) {
        ensureOpen()
        val code = Verity.saveProver(handle, path)
        if (code != 0) throw VerityException.fromCode(code)
    }

    /**
     * Serialize the prover scheme to bytes.
     *
     * The output is the same format as [save] writes to disk.
     * Use [Verity.loadProver] with bytes to restore.
     *
     * @return Serialized bytes.
     */
    fun serialize(): ByteArray {
        ensureOpen()
        return Verity.serializeProver(handle)
    }

    override fun close() {
        synchronized(this) {
            if (!closed) {
                closed = true
                Verity.freeProver(handle)
            }
        }
    }

}
