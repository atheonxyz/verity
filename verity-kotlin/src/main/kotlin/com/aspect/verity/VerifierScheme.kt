package com.aspect.verity

/**
 * Opaque handle to a compiled verifier scheme.
 *
 * Created by [Verity.prepare] or [Verity.loadVerifier].
 * This class is thread-safe: it can be shared across threads for
 * concurrent verify calls. Must be [close]d when no longer needed
 * (or use [use]).
 *
 * A safety-net finalizer will free the native handle if [close] is
 * never called, but relying on this is discouraged — always prefer
 * explicit [close] or Kotlin's [use] block.
 */
// Thread-safe: @Volatile closed flag + @Synchronized close/ensureOpen
class VerifierScheme internal constructor(internal val handle: Long) : AutoCloseable {

    @Volatile
    private var closed = false

    @Synchronized
    internal fun ensureOpen() {
        check(!closed) { "VerifierScheme is closed" }
    }

    /**
     * Save the verifier scheme to a file.
     *
     * @param path Destination file path.
     */
    fun save(path: String) {
        ensureOpen()
        val code = Verity.saveVerifier(handle, path)
        if (code != 0) throw VerityException.fromCode(code)
    }

    /**
     * Serialize the verifier scheme to bytes.
     *
     * The output is the same format as [save] writes to disk.
     * Use [Verity.loadVerifier] with bytes to restore.
     *
     * @return Serialized bytes.
     */
    fun serialize(): ByteArray {
        ensureOpen()
        return Verity.serializeVerifier(handle)
    }

    override fun close() {
        synchronized(this) {
            if (!closed) {
                closed = true
                Verity.freeVerifier(handle)
            }
        }
    }

    protected fun finalize() {
        if (!closed) {
            close()
        }
    }
}
