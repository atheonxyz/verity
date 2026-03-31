import Foundation

/// Errors returned by Verity operations.
public enum VerityError: LocalizedError, Equatable {
    /// Invalid input provided to an FFI function.
    case invalidInput(String)
    /// Failed to read scheme/circuit file.
    case schemeReadError
    /// Proof generation failed.
    case proofFailed(String)
    /// Serialization error.
    case serializationError
    /// Circuit compilation failed.
    case compilationFailed(String)
    /// Unknown or unregistered backend.
    case unknownBackend
    /// Memory allocation failed.
    case outOfMemory
    /// The underlying FFI handle has been freed via `close()`.
    case resourceClosed(String)
    /// Unknown FFI error with raw code.
    case ffiError(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        case .schemeReadError:
            return "Failed to read scheme or circuit file. Check that the file path exists and is readable."
        case .proofFailed(let msg):
            return "Proof generation failed: \(msg)"
        case .serializationError:
            return "Serialization error. The data may be corrupted or from an incompatible version."
        case .compilationFailed(let msg):
            return "Circuit compilation failed: \(msg). Ensure the circuit JSON was produced by `nargo compile`."
        case .unknownBackend:
            return "Unknown backend. Use .provekit or .barretenberg."
        case .outOfMemory:
            return "Memory allocation failed. Consider configuring memory limits with Verity.configureMemory()."
        case .resourceClosed(let msg):
            return msg
        case .ffiError(let code):
            return "Internal FFI error (code \(code)). Please report this at https://github.com/atheonxyz/verity/issues"
        }
    }

    /// Map an FFI error code to a typed Swift error.
    internal static func fromCode(_ code: Int32) -> VerityError {
        switch code {
        case 0: preconditionFailure("VerityError.fromCode called with success code 0")
        case 1: return .invalidInput("null pointer or empty data — check that all paths and buffers are non-empty")
        case 2: return .schemeReadError
        case 3: return .invalidInput("failed to parse witness/input file — check TOML syntax")
        case 4: return .proofFailed("proof generation or verification error")
        case 5: return .serializationError
        case 6: return .invalidInput("string contains invalid UTF-8")
        case 7: return .invalidInput("file write error — check that the destination directory exists and is writable")
        case 8: return .compilationFailed("circuit compilation error")
        case 9: return .unknownBackend
        case 10: return .outOfMemory
        default: return .ffiError(code: code)
        }
    }
}
