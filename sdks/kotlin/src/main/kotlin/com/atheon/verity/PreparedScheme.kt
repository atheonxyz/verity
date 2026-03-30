package com.atheon.verity

/**
 * Result of [Verity.prepare] — holds both prover and verifier schemes.
 *
 * Both schemes are independent and can be used separately.
 * Each must be [AutoCloseable.close]d when no longer needed.
 */
class PreparedScheme(
    /** Prover scheme — call [ProverScheme.prove] to generate proofs. */
    val prover: ProverScheme,
    /** Verifier scheme — call [VerifierScheme.verify] to check proofs. */
    val verifier: VerifierScheme,
) : AutoCloseable {

    /** Close both prover and verifier schemes. */
    override fun close() {
        try {
            prover.close()
        } finally {
            verifier.close()
        }
    }
}
