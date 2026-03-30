package com.atheon.verity

import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Opaque handle to a compiled prover scheme.
 *
 * Created by [Verity.prepare] or [Verity.loadProver].
 * Thread-safe: can be reused for concurrent prove calls.
 * Must be [close]d when no longer needed (or use [use]).
 */
class ProverScheme internal constructor(private var handle: Long) : AutoCloseable {

    private val lock = ReentrantReadWriteLock()
    private var closed = false

    internal fun <T> useHandle(block: (Long) -> T): T = lock.read {
        check(!closed) { "ProverScheme is closed" }
        block(handle)
    }

    // MARK: - Prove

    /**
     * Generate a proof from witness values.
     *
     * ```kotlin
     * val witness = Witness.load("Prover.toml")
     * val proof   = prover.prove(witness)
     * ```
     *
     * @param witness A [Witness] containing the circuit's private inputs.
     * @return A [Proof] containing the proof bytes.
     */
    @Throws(VerityException::class)
    fun prove(witness: Witness): Proof = useHandle { handle ->
        when (val resolved = witness.resolve()) {
            is Witness.Resolved.TomlPath -> {
                require(resolved.path.isNotEmpty()) { "input path cannot be empty" }
                Proof(Verity.nativeProveToml(handle, resolved.path))
            }
            is Witness.Resolved.Json -> {
                Proof(Verity.nativeProveJson(handle, resolved.json))
            }
        }
    }

    // MARK: - Save / Serialize

    /**
     * Save the prover scheme to a file.
     *
     * @param path Destination file path.
     */
    @Throws(VerityException::class)
    fun save(path: String) = useHandle { handle ->
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
    @Throws(VerityException::class)
    fun serialize(): ByteArray = useHandle { handle ->
        Verity.serializeProver(handle)
    }

    override fun close() = lock.write {
        if (!closed) {
            closed = true
            val h = handle
            handle = 0L
            Verity.freeProver(h)
        }
    }

    @Suppress("removal")
    protected fun finalize() {
        close()
    }
}
