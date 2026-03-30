package com.atheon.veritydemo

import com.atheon.verity.Backend

data class ProofResult(
    val circuit: Circuit,
    val backend: Backend,
    val proofBytes: ByteArray,
    val prepareTimeMs: Long,
    val proveTimeMs: Long,
    val verifyTimeMs: Long,
    val isValid: Boolean,
    val nativeMemoryMB: Long,
) {
    val proofSizeBytes: Int get() = proofBytes.size

    val totalTimeMs: Long get() = prepareTimeMs + proveTimeMs + verifyTimeMs

    val proofHex: String
        get() = proofBytes.joinToString("") { "%02x".format(it) }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ProofResult) return false
        return circuit == other.circuit &&
            backend == other.backend &&
            proofBytes.contentEquals(other.proofBytes) &&
            prepareTimeMs == other.prepareTimeMs &&
            proveTimeMs == other.proveTimeMs &&
            verifyTimeMs == other.verifyTimeMs &&
            isValid == other.isValid &&
            nativeMemoryMB == other.nativeMemoryMB
    }

    override fun hashCode(): Int {
        var result = circuit.hashCode()
        result = 31 * result + backend.hashCode()
        result = 31 * result + proofBytes.contentHashCode()
        return result
    }
}
