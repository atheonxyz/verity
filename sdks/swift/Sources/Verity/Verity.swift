import Foundation
import VerityDispatch

/// Available proving backends.
public enum Backend: UInt32, CaseIterable, Sendable, CustomStringConvertible {
    /// ProveKit WHIR backend (transparent, hash-based).
    case provekit = 0       // matches VERITY_BACKEND_PROVEKIT
    /// Barretenberg UltraHonk backend (KZG commitments).
    case barretenberg = 1   // matches VERITY_BACKEND_BARRETENBERG

    /// Convert to the C VerityBackend type.
    internal var cValue: VerityBackend {
        VerityBackend(rawValue)
    }

    public var description: String {
        switch self {
        case .provekit: return "ProveKit"
        case .barretenberg: return "Barretenberg"
        }
    }
}

public enum RuntimeMode: String, Sendable {
    case sourceOnly = "source-only"
    case native
}

/// Verity — zero-knowledge proof SDK.
///
/// `Verity` is a factory for loading prover and verifier schemes.
/// Use the schemes directly to generate and verify proofs.
///
/// ```swift
/// let verity   = try Verity(backend: .provekit)
/// let prover   = try verity.loadProver(from: "prover.pkp")
/// let verifier = try verity.loadVerifier(from: "verifier.pkv")
/// let witness  = try Witness.load(from: "Prover.toml")
/// let proof    = try prover.prove(witness: witness)
/// let valid    = try verifier.verify(proof: proof)
/// ```
public final class Verity: @unchecked Sendable {
    private static let lock = NSLock()
    private static var initializedBackends: Set<UInt32> = []
    private let backend: Backend

    /// The SDK version string (e.g., `"0.2.0"`).
    public static let version = "0.3.0"

    public static let runtimeMode: RuntimeMode = {
        #if VERITY_SWIFT_NATIVE_RUNTIME
        return .native
        #else
        return .sourceOnly
        #endif
    }()

    /// Create a Verity instance with the specified backend.
    ///
    /// Automatically initializes the backend on first use. Thread-safe.
    public init(backend: Backend) throws {
        try Verity.lock.withLock {
            if !Verity.initializedBackends.contains(backend.rawValue) {
                let code = verity_init(backend.cValue)
                guard code == 0 else {
                    throw VerityError.fromCode(code)
                }
                Verity.initializedBackends.insert(backend.rawValue)
            }
        }
        self.backend = backend
    }

    public static func lastErrorMessage(for backend: Backend) throws -> String? {
        var buf = VerityBuf(ptr: nil, len: 0, cap: 0, backend: 0)
        let code = verity_last_error_message(backend.cValue, &buf)
        guard code == 0 else {
            throw VerityError.fromCode(code)
        }
        defer {
            if buf.ptr != nil {
                verity_free_buf(buf)
            }
        }
        guard let ptr = buf.ptr, buf.len > 0 else {
            return nil
        }
        return String(decoding: UnsafeBufferPointer(start: ptr, count: Int(buf.len)), as: UTF8.self)
    }

    // MARK: - Load

    /// Load a prover scheme from a file.
    ///
    /// - Parameter path: Path to saved prover file.
    /// - Returns: A ``ProverScheme`` handle.
    public func loadProver(from path: String) throws -> ProverScheme {
        var handle: OpaquePointer?
        let code = verity_load_prover(backend.cValue, path, &handle)
        guard code == 0, let handle else { throw VerityError.fromCode(code) }
        return ProverScheme(handle: handle)
    }

    /// Load a prover scheme from a URL.
    ///
    /// - Parameter url: URL pointing to saved prover file.
    /// - Returns: A ``ProverScheme`` handle.
    public func loadProver(from url: URL) throws -> ProverScheme {
        try loadProver(from: url.path)
    }

    /// Load a prover scheme from bytes.
    ///
    /// Accepts the same format as saved files — useful for data downloaded
    /// from a URL or bundled in an app.
    ///
    /// - Parameter data: Serialized prover bytes.
    /// - Returns: A ``ProverScheme`` handle.
    public func loadProver(data: Data) throws -> ProverScheme {
        return try data.withUnsafeBytes { bytes -> ProverScheme in
            guard let base = bytes.baseAddress else {
                throw VerityError.invalidInput("empty data")
            }
            var handle: OpaquePointer?
            let code = verity_load_prover_bytes(
                backend.cValue,
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                &handle
            )
            guard code == 0, let handle else { throw VerityError.fromCode(code) }
            return ProverScheme(handle: handle)
        }
    }

    /// Load a verifier scheme from a file.
    ///
    /// - Parameter path: Path to saved verifier file.
    /// - Returns: A ``VerifierScheme`` handle.
    public func loadVerifier(from path: String) throws -> VerifierScheme {
        var handle: OpaquePointer?
        let code = verity_load_verifier(backend.cValue, path, &handle)
        guard code == 0, let handle else { throw VerityError.fromCode(code) }
        return VerifierScheme(handle: handle)
    }

    /// Load a verifier scheme from a URL.
    ///
    /// - Parameter url: URL pointing to saved verifier file.
    /// - Returns: A ``VerifierScheme`` handle.
    public func loadVerifier(from url: URL) throws -> VerifierScheme {
        try loadVerifier(from: url.path)
    }

    /// Load a verifier scheme from bytes.
    ///
    /// Accepts the same format as saved files — useful for data downloaded
    /// from a URL or bundled in an app.
    ///
    /// - Parameter data: Serialized verifier bytes.
    /// - Returns: A ``VerifierScheme`` handle.
    public func loadVerifier(data: Data) throws -> VerifierScheme {
        return try data.withUnsafeBytes { bytes -> VerifierScheme in
            guard let base = bytes.baseAddress else {
                throw VerityError.invalidInput("empty data")
            }
            var handle: OpaquePointer?
            let code = verity_load_verifier_bytes(
                backend.cValue,
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                &handle
            )
            guard code == 0, let handle else { throw VerityError.fromCode(code) }
            return VerifierScheme(handle: handle)
        }
    }

    // MARK: - Prove / Verify (convenience)

    /// Generate a proof using a prover scheme and witness values.
    ///
    /// Convenience method — equivalent to `prover.prove(witness: witness)`.
    ///
    /// - Parameters:
    ///   - prover: A ``ProverScheme`` from ``loadProver(from:)``.
    ///   - witness: A ``Witness`` containing the circuit's private inputs.
    /// - Returns: A ``Proof`` containing the proof bytes.
    public func prove(with prover: ProverScheme, witness: Witness) throws -> Proof {
        try prover.prove(witness: witness)
    }

    /// Verify a proof using a verifier scheme.
    ///
    /// Convenience method — equivalent to `verifier.verify(proof: proof)`.
    ///
    /// - Parameters:
    ///   - verifier: A ``VerifierScheme`` from ``loadVerifier(from:)``.
    ///   - proof: A ``Proof`` from ``ProverScheme/prove(witness:)``.
    /// - Returns: `true` if proof is valid, `false` if mathematically invalid.
    public func verify(with verifier: VerifierScheme, proof: Proof) throws -> Bool {
        try verifier.verify(proof: proof)
    }

    // MARK: - Memory Configuration (ProveKit)

    /// Configure the ProveKit memory allocator.
    ///
    /// Call before ``init(backend:)`` to limit RAM usage and enable file-backed
    /// memory for large circuits on memory-constrained devices (e.g., mobile).
    ///
    /// Only applies to the ProveKit backend.
    ///
    /// - Parameters:
    ///   - ramLimit: Maximum RAM for the prover in bytes (0 = unlimited).
    ///   - useFileBacked: If true, spill allocations to a swap file.
    ///   - swapFilePath: Path to swap file (required if `useFileBacked` is true).
    public static func configureMemory(
        ramLimit: UInt = 0,
        useFileBacked: Bool = false,
        swapFilePath: String? = nil
    ) throws {
        let code = verity_pk_configure_memory(ramLimit, useFileBacked, swapFilePath)
        guard code == 0 else { throw VerityError.fromCode(code) }
    }

    /// Get current ProveKit memory usage statistics.
    ///
    /// Only applies to the ProveKit backend.
    ///
    /// - Returns: A tuple of (ramUsed, swapUsed, peakRam) in bytes.
    public static func memoryStats() throws -> (ramUsed: UInt, swapUsed: UInt, peakRam: UInt) {
        var ramUsed: UInt = 0
        var swapUsed: UInt = 0
        var peakRam: UInt = 0
        let code = verity_pk_get_memory_stats(&ramUsed, &swapUsed, &peakRam)
        guard code == 0 else { throw VerityError.fromCode(code) }
        return (ramUsed, swapUsed, peakRam)
    }
}
