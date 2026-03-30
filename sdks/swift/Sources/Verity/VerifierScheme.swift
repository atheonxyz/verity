import Foundation
import VerityDispatch

/// Opaque handle to a compiled verifier scheme.
///
/// Created by ``Verity/prepare(circuit:)`` or ``Verity/loadVerifier(from:)``.
/// Thread-safe. Automatically freed on deinit.
/// Can be reused for multiple verify calls.
public final class VerifierScheme: @unchecked Sendable {
    internal let handle: OpaquePointer

    internal init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        verity_free_verifier(handle)
    }

    /// Save the verifier scheme to a file.
    ///
    /// - Parameter path: Destination file path.
    public func save(to path: String) throws {
        let code = verity_save_verifier(handle, path)
        guard code == 0 else { throw VerityError.fromCode(code) }
    }

    /// Serialize the verifier scheme to bytes.
    ///
    /// The output is the same format as ``save(to:)`` writes to disk.
    /// Use ``Verity/loadVerifier(data:)`` to restore.
    ///
    /// - Returns: Serialized bytes.
    public func serialize() throws -> Data {
        var buf = VerityBuf(ptr: nil, len: 0, cap: 0)
        let code = verity_serialize_verifier(handle, &buf)
        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.serializationError
        }
        let data = Data(bytes: ptr, count: Int(buf.len))
        verity_free_buf(buf)
        return data
    }
}
