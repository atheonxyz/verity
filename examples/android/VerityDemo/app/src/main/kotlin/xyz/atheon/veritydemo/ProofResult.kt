package xyz.atheon.veritydemo

import xyz.atheon.verity.Backend
import xyz.atheon.verity.Proof

data class ProofResult(
    val circuit: DemoCircuit,
    val backend: Backend,
    val proof: Proof,
    val prepareTimeMs: Long,
    val proveTimeMs: Long,
    val verifyTimeMs: Long,
    val isValid: Boolean,
    val nativeMemoryMB: Long,
    val usedPrecompiled: Boolean = false,
) {
    val totalTimeMs: Long get() = prepareTimeMs + proveTimeMs + verifyTimeMs
    val proofSize: Int get() = proof.size
}
