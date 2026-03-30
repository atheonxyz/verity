package com.atheon.verity

/** Errors returned by Verity operations. */
sealed class VerityException(message: String, cause: Throwable? = null) : Exception(message, cause) {

    /** Invalid input provided to an FFI function. */
    class InvalidInput(detail: String) : VerityException("Invalid input: $detail")

    /** Failed to read scheme or circuit file. Check that the file path exists and is readable. */
    class SchemeReadError : VerityException("Failed to read scheme/circuit file. Check that the path exists and is readable.")

    /** Proof generation failed. */
    class ProofFailed(detail: String) : VerityException("Proof generation failed: $detail")

    /** Proof verification failed (proof is invalid, not an error). */
    class VerificationFailed : VerityException("Proof verification failed.")

    /** Serialization error. The data may be corrupted or from an incompatible version. */
    class SerializationError : VerityException("Serialization error. Data may be corrupted or from an incompatible version.")

    /** Circuit compilation failed. Ensure the circuit JSON was produced by `nargo compile`. */
    class CompilationFailed(detail: String) : VerityException("Compilation failed: $detail. Ensure the circuit JSON was produced by `nargo compile`.")

    /** Unknown backend. Use `Backend.PROVEKIT` or `Backend.BARRETENBERG`. */
    class UnknownBackend : VerityException("Unknown backend. Use Backend.PROVEKIT or Backend.BARRETENBERG.")

    /** Memory allocation failed. */
    class OutOfMemory : VerityException("Memory allocation failed. Consider configuring memory limits with Verity.configureMemory().")

    /** Internal FFI error. Please report at https://github.com/atheonxyz/verity/issues */
    class FfiError(code: Int) : VerityException("Internal FFI error (code $code). Please report at https://github.com/atheonxyz/verity/issues")

    companion object {
        /** Map an FFI error code to a typed exception. */
        @JvmStatic
        fun fromCode(code: Int): VerityException = when (code) {
            1 -> InvalidInput("null pointer or empty data — check that all paths and buffers are non-empty")
            2 -> SchemeReadError()
            3 -> InvalidInput("failed to parse witness/input file — check TOML syntax")
            // Note: VerifierScheme.verify() intercepts code 4 and returns false instead of throwing.
            // This mapping exists for contexts outside verify() (e.g. prove errors).
            4 -> VerificationFailed()
            5 -> SerializationError()
            6 -> InvalidInput("string contains invalid UTF-8")
            7 -> InvalidInput("file write error — check that the destination directory exists and is writable")
            8 -> CompilationFailed("circuit compilation error")
            9 -> UnknownBackend()
            10 -> OutOfMemory()
            else -> FfiError(code)
        }
    }
}
