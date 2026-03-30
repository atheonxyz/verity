package atheon.verity

/** Errors returned by Verity operations. */
sealed class VerityException(message: String) : Exception(message) {

    /** Library not initialized. */
    class NotInitialized : VerityException("Verity not initialized.")

    /** Invalid input provided to an FFI function. */
    class InvalidInput(detail: String) : VerityException("Invalid input: $detail")

    /** Failed to read scheme/circuit file. */
    class SchemeReadError : VerityException("Failed to read scheme/circuit file")

    /** Proof generation failed. */
    class ProofFailed(detail: String) : VerityException("Proof generation failed: $detail")

    /** Proof verification failed (proof is invalid, not an error). */
    class VerificationFailed : VerityException("Proof verification failed")

    /** Serialization error. */
    class SerializationError : VerityException("Serialization error")

    /** Circuit compilation failed. */
    class CompilationFailed(detail: String) : VerityException("Compilation failed: $detail")

    /** Unknown or unregistered backend. */
    class UnknownBackend : VerityException("Unknown or unregistered backend")

    /** Unknown FFI error with raw code. */
    class FfiError(code: Int) : VerityException("FFI error code: $code")

    companion object {
        /** Map an FFI error code to a typed exception. */
        @JvmStatic
        fun fromCode(code: Int): VerityException = when (code) {
            1 -> InvalidInput("null pointer or empty data")
            2 -> SchemeReadError()
            3 -> InvalidInput("witness read error")
            // Note: Verity.verify() intercepts code 4 and returns false instead of throwing.
            // This mapping exists for contexts outside verify() (e.g. prove errors).
            4 -> VerificationFailed()
            5 -> SerializationError()
            6 -> InvalidInput("UTF-8 error")
            7 -> InvalidInput("file write error")
            8 -> CompilationFailed("circuit compilation error")
            9 -> UnknownBackend()
            else -> FfiError(code)
        }
    }
}
