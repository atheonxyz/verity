package com.aspect.verity

/**
 * Opaque handle to a compiled prover scheme.
 *
 * Created by [Verity.prepare] or [Verity.loadProver].
 * This class is thread-safe: it can be shared across threads for
 * concurrent prove calls. Must be [close]d when no longer needed
 * (or use [use]).
 *
 * A safety-net finalizer will free the native handle if [close] is
 * never called, but relying on this is discouraged — always prefer
 * explicit [close] or Kotlin's [use] block.
 */
// Thread-safe: @Volatile closed flag + @Synchronized close/ensureOpen
class ProverScheme internal constructor(internal val handle: Long) : AutoCloseable {

    @Volatile
    private var closed = false

    @Synchronized
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

    protected fun finalize() {
        if (!closed) {
            close()
        }
    }
}
