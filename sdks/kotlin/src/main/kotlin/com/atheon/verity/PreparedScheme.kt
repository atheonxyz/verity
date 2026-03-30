package com.aspect.verity

/**
 * Result of [Verity.prepare] — holds both prover and verifier schemes.
 *
 * Both schemes are independent and can be used separately.
 * Each must be [AutoCloseable.close]d when no longer needed.
 */
class PreparedScheme(
    /** Prover scheme — pass to [Verity.prove]. */
    val prover: ProverScheme,
    /** Verifier scheme — pass to [Verity.verify]. */
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
