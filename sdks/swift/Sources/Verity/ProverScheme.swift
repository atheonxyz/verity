import Foundation
import VerityDispatch

/// Opaque handle to a compiled prover scheme.
///
/// Created by ``Verity/loadProver(from:)``.
/// Automatically freed on deinit. Can be reused for multiple prove calls.
///
/// Thread-safe: all operations are internally synchronized.
public final class ProverScheme: @unchecked Sendable {
    internal var handle: OpaquePointer?
    private let lock = NSLock()

    internal init(handle: OpaquePointer) {
        self.handle = handle
    }

    internal init() {
        self.handle = nil
    }

    deinit {
        close()
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return }
        self.handle = nil
        verity_free_prover(handle)
    }

    // MARK: - Prove

    /// Generate a proof from witness values.
    ///
    /// ```swift
    /// let witness = try Witness.load(from: "Prover.toml")
    /// let proof   = try prover.prove(witness: witness)
    /// ```
    ///
    /// - Parameter witness: A ``Witness`` containing the circuit's private inputs.
    /// - Returns: A ``Proof`` containing the proof bytes.
    public func prove(witness: Witness) throws -> Proof {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else {
            throw VerityError.resourceClosed("FFI handle is closed")
        }

        var buf = VerityBuf(ptr: nil, len: 0, cap: 0, backend: 0)
        let code: Int32

        switch try witness.resolve() {
        case .tomlPath(let path):
            code = verity_prove_toml(handle, path, &buf)
        case .json(let json):
            code = verity_prove_json(handle, json, &buf)
        }

        defer { if buf.ptr != nil { verity_free_buf(buf) } }
        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.proofFailed("empty proof returned")
        }

        return Proof(data: Data(bytes: ptr, count: Int(buf.len)))
    }

    // MARK: - Save / Serialize

    /// Save the prover scheme to a file.
    ///
    /// - Parameter path: Destination file path.
    public func save(to path: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else {
            throw VerityError.resourceClosed("FFI handle is closed")
        }
        let code = verity_save_prover(handle, path)
        guard code == 0 else { throw VerityError.fromCode(code) }
    }

    /// Save the prover scheme to a URL.
    ///
    /// - Parameter url: Destination file URL.
    public func save(to url: URL) throws {
        try save(to: url.path)
    }

    /// Serialize the prover scheme to bytes.
    ///
    /// The output is the same format as ``save(to:)`` writes to disk.
    /// Use ``Verity/loadProver(data:)`` to restore.
    ///
    /// - Returns: Serialized bytes.
    public func serialize() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else {
            throw VerityError.resourceClosed("FFI handle is closed")
        }
        var buf = VerityBuf(ptr: nil, len: 0, cap: 0, backend: 0)
        let code = verity_serialize_prover(handle, &buf)
        defer { if buf.ptr != nil { verity_free_buf(buf) } }
        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.serializationError
        }
        return Data(bytes: ptr, count: Int(buf.len))
    }
}
