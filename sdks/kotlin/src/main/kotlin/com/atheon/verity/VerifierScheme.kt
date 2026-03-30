package com.atheon.verity

import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Opaque handle to a compiled verifier scheme.
 *
 * Created by [Verity.prepare] or [Verity.loadVerifier].
 * Thread-safe: can be reused for concurrent verify calls.
 * Must be [close]d when no longer needed (or use [use]).
 */
class VerifierScheme internal constructor(private var handle: Long) : AutoCloseable {

    private val lock = ReentrantReadWriteLock()
    private var closed = false

    internal fun <T> useHandle(block: (Long) -> T): T = lock.read {
        check(!closed) { "VerifierScheme is closed" }
        block(handle)
    }

    // MARK: - Verify

    /**
     * Verify a proof.
     *
     * ```kotlin
     * val valid = verifier.verify(proof)
     * ```
     *
     * @param proof A [Proof] from [ProverScheme.prove].
     * @return `true` if proof is valid, `false` if mathematically invalid.
     */
    @Throws(VerityException::class)
    fun verify(proof: Proof): Boolean = useHandle { handle ->
        require(proof.data.isNotEmpty()) { "proof cannot be empty" }
        val code = Verity.nativeVerify(handle, proof.data)
        when (code) {
            0 -> true
            4 -> false  // PROOF_ERROR = proof is mathematically invalid
            else -> throw VerityException.fromCode(code)
        }
    }

    // MARK: - Save / Serialize

    /**
     * Save the verifier scheme to a file.
     *
     * @param path Destination file path.
     */
    @Throws(VerityException::class)
    fun save(path: String) = useHandle { handle ->
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
    @Throws(VerityException::class)
    fun serialize(): ByteArray = useHandle { handle ->
        Verity.serializeVerifier(handle)
    }

    override fun close() = lock.write {
        if (!closed) {
            closed = true
            val h = handle
            handle = 0L
            Verity.freeVerifier(h)
        }
    }

    @Suppress("removal")
    protected fun finalize() {
        close()
    }
}
