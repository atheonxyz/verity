import Foundation

/// Errors returned by Verity operations.
public enum VerityError: LocalizedError {
    /// Library not initialized.
    case notInitialized
    /// Invalid input provided to an FFI function.
    case invalidInput(String)
    /// Failed to read scheme/circuit file.
    case schemeReadError
    /// Proof generation failed.
    case proofFailed(String)
    /// Proof verification failed.
    case verificationFailed
    /// Serialization error.
    case serializationError
    /// Circuit compilation failed.
    case compilationFailed(String)
    /// Unknown or unregistered backend.
    case unknownBackend
    /// Unknown FFI error with raw code.
    case ffiError(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Verity not initialized."
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        case .schemeReadError:
            return "Failed to read scheme/circuit file"
        case .proofFailed(let msg):
            return "Proof generation failed: \(msg)"
        case .verificationFailed:
            return "Proof verification failed"
        case .serializationError:
            return "Serialization error"
        case .compilationFailed(let msg):
            return "Compilation failed: \(msg)"
        case .unknownBackend:
            return "Unknown or unregistered backend"
        case .ffiError(let code):
            return "FFI error code: \(code)"
        }
    }

    /// Map an FFI error code to a typed Swift error.
    static func fromCode(_ code: Int32) -> VerityError {
        switch code {
        case 1: return .invalidInput("null pointer or empty data")
        case 2: return .schemeReadError
        case 3: return .invalidInput("witness read error")
        case 4: return .proofFailed("proof generation or verification error")
        case 5: return .serializationError
        case 6: return .invalidInput("UTF-8 error")
        case 7: return .invalidInput("file write error")
        case 8: return .compilationFailed("circuit compilation error")
        case 9: return .unknownBackend
        default: return .ffiError(code: code)
        }
    }
}
