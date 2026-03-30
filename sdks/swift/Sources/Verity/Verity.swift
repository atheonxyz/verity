import Foundation
import VerityDispatch

/// Available proving backends.
public enum Backend: UInt32 {
    /// ProveKit WHIR backend (transparent, hash-based).
    case provekit = 0       // matches VERITY_BACKEND_PROVEKIT
    /// Barretenberg UltraHonk backend (KZG commitments).
    case barretenberg = 1   // matches VERITY_BACKEND_BARRETENBERG

    /// Convert to the C VerityBackend type.
    internal var cValue: VerityBackend {
        VerityBackend(rawValue)
    }
}

/// Result of ``Verity/prepare(circuit:)``.
public struct PreparedScheme {
    /// Prover scheme — pass to ``Verity/prove(with:input:)`` or
    /// ``Verity/prove(with:inputs:)``.
    public let prover: ProverScheme
    /// Verifier scheme — pass to ``Verity/verify(with:proof:)``.
    public let verifier: VerifierScheme
}

/// Verity — generate and verify zero-knowledge proofs.
///
/// Usage:
/// ```swift
/// let verity = try Verity(backend: .provekit)
/// let scheme = try verity.prepare(circuit: "circuit.json")
/// let proof  = try verity.prove(with: scheme.prover, inputs: ["x": "5"])
/// let valid  = try verity.verify(with: scheme.verifier, proof: proof)
/// ```
public final class Verity {
    private static var initializedBackends: Set<UInt32> = []
    private let backend: Backend

    /// Create a Verity instance with the specified backend.
    ///
    /// Automatically initializes the backend on first use.
    public init(backend: Backend) throws {
        if !Verity.initializedBackends.contains(backend.rawValue) {
            let code = verity_init(backend.cValue)
            guard code == 0 else {
                throw VerityError.fromCode(code)
            }
            Verity.initializedBackends.insert(backend.rawValue)
        }
        self.backend = backend
    }

    // MARK: - Prepare

    /// Compile a circuit into prover and verifier schemes.
    ///
    /// No files are written — both schemes live in memory.
    ///
    /// - Parameter circuit: Path to compiled circuit (ACIR JSON from `nargo compile`).
    /// - Returns: A ``PreparedScheme`` containing both prover and verifier.
    public func prepare(circuit: String) throws -> PreparedScheme {
        var proverHandle: OpaquePointer?
        var verifierHandle: OpaquePointer?
        let code = verity_prepare(backend.cValue, circuit, &proverHandle, &verifierHandle)

        guard code == 0, let pk = proverHandle, let vk = verifierHandle else {
            throw VerityError.fromCode(code)
        }

        return PreparedScheme(
            prover: ProverScheme(handle: pk),
            verifier: VerifierScheme(handle: vk)
        )
    }

    // MARK: - Prove

    /// Generate a proof using a TOML input file.
    ///
    /// - Parameters:
    ///   - prover: Prover scheme from ``prepare(circuit:)`` or ``loadProver(from:)``.
    ///   - input: Path to input file (.toml).
    /// - Returns: Proof bytes as `Data`.
    public func prove(with prover: ProverScheme, input: String) throws -> Data {
        var buf = VerityBuf(ptr: nil, len: 0, cap: 0)
        let code = verity_prove_toml(prover.handle, input, &buf)

        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.proofFailed("empty proof returned")
        }

        let data = Data(bytes: ptr, count: Int(buf.len))
        verity_free_buf(buf)
        return data
    }

    /// Generate a proof using a dictionary of inputs.
    ///
    /// Values are serialized to JSON and parsed by the circuit's ABI.
    /// Field elements should be strings (e.g., `"5"` or `"0x1a2b..."`).
    ///
    /// - Parameters:
    ///   - prover: Prover scheme from ``prepare(circuit:)`` or ``loadProver(from:)``.
    ///   - inputs: Dictionary mapping parameter names to values.
    /// - Returns: Proof bytes as `Data`.
    public func prove(with prover: ProverScheme, inputs: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(inputs) else {
            throw VerityError.invalidInput("inputs dictionary is not valid JSON")
        }
        let jsonData = try JSONSerialization.data(withJSONObject: inputs)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw VerityError.serializationError
        }

        var buf = VerityBuf(ptr: nil, len: 0, cap: 0)
        let code = verity_prove_json(prover.handle, jsonString, &buf)

        guard code == 0 else { throw VerityError.fromCode(code) }
        guard let ptr = buf.ptr, buf.len > 0 else {
            throw VerityError.proofFailed("empty proof returned")
        }

        let data = Data(bytes: ptr, count: Int(buf.len))
        verity_free_buf(buf)
        return data
    }

    // MARK: - Verify

    /// Verify a proof.
    ///
    /// - Parameters:
    ///   - verifier: Verifier scheme from ``prepare(circuit:)`` or ``loadVerifier(from:)``.
    ///   - proof: Proof bytes (from ``prove(with:input:)`` or ``prove(with:inputs:)``).
    /// - Returns: `true` if proof is valid.
    public func verify(with verifier: VerifierScheme, proof: Data) throws -> Bool {
        let code = proof.withUnsafeBytes { bytes -> Int32 in
            guard let base = bytes.baseAddress else { return 1 }
            return verity_verify(
                verifier.handle,
                base.assumingMemoryBound(to: UInt8.self),
                UInt(proof.count)
            )
        }

        switch code {
        case 0: return true
        case 4: return false
        default: throw VerityError.fromCode(code)
        }
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
}
