import Foundation
import VerityDispatch

/// Opaque handle to a compiled verifier scheme.
///
/// Created by ``Verity/prepare(circuit:)`` or ``Verity/loadVerifier(from:)``.
/// Automatically freed on deinit. Can be reused for multiple verify calls.
///
/// Thread-safe: all operations are internally synchronized.
public final class VerifierScheme: @unchecked Sendable {
    internal let handle: OpaquePointer
    private let lock = NSLock()

    internal init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        verity_free_verifier(handle)
    }

    // MARK: - Verify

    /// Verify a proof.
    ///
    /// ```swift
    /// let valid = try verifier.verify(proof: proof)
    /// ```
    ///
    /// - Parameter proof: A ``Proof`` from ``ProverScheme/prove(witness:)``.
    /// - Returns: `true` if proof is valid, `false` if mathematically invalid.
    public func verify(proof: Proof) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let proofData = proof.data
        let code = proofData.withUnsafeBytes { bytes -> Int32 in
            guard let base = bytes.baseAddress else {
                return Int32(VERITY_INVALID_INPUT.rawValue)
            }
            return verity_verify(
                handle,
                base.assumingMemoryBound(to: UInt8.self),
                UInt(proofData.count)
            )
        }

        switch code {
        case 0: return true
        case 4: return false  // PROOF_ERROR = proof is mathematically invalid
        default: throw VerityError.fromCode(code)
        }
    }

    // MARK: - Save / Serialize

    /// Save the verifier scheme to a file.
    ///
    /// - Parameter path: Destination file path.
    public func save(to path: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let code = verity_save_verifier(handle, path)
        guard code == 0 else { throw VerityError.fromCode(code) }
    }

    /// Save the verifier scheme to a URL.
    ///
    /// - Parameter url: Destination file URL.
    public func save(to url: URL) throws {
        try save(to: url.path)
    }

    /// Serialize the verifier scheme to bytes.
    ///
    /// The output is the same format as ``save(to:)`` writes to disk.
    /// Use ``Verity/loadVerifier(data:)`` to restore.
    ///
    /// - Returns: Serialized bytes.
    public func serialize() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        var buf = VerityBuf(ptr: nil, len: 0, cap: 0, backend: 0)
        let code = verity_serialize_verifier(handle, &buf)
        defer { if buf.ptr != nil { verity_free_buf(buf) } }
        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.serializationError
        }
        return Data(bytes: ptr, count: Int(buf.len))
    }
}
