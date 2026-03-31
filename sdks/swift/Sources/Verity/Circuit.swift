import Foundation

/// A compiled circuit (ACIR JSON from `nargo compile`).
///
/// Load a circuit first, then pass it to ``Verity/prepare(circuit:)``.
///
/// ```swift
/// let circuit = try Circuit.load(from: "/path/to/circuit.json")
/// let circuit = try Circuit.load(url: Bundle.main.url(forResource: "circuit", withExtension: "json")!)
/// let scheme  = try verity.prepare(circuit: circuit)
/// ```
public struct Circuit: Sendable {
    /// The raw circuit JSON data.
    public let data: Data

    /// Original file path, if loaded from a file.
    private let sourcePath: String?

    /// Create a circuit from raw JSON data.
    ///
    /// - Parameter data: ACIR JSON bytes (from `nargo compile`).
    public init(data: Data) {
        self.data = data
        self.sourcePath = nil
    }

    public static func fromBytes(_ data: Data) -> Circuit {
        Circuit(data: data)
    }

    private init(data: Data, sourcePath: String) {
        self.data = data
        self.sourcePath = sourcePath
    }

    /// Load a circuit from a file path.
    ///
    /// - Parameter path: Path to compiled circuit JSON file.
    /// - Throws: ``VerityError/invalidInput(_:)`` if the file cannot be read.
    public static func load(from path: String) throws -> Circuit {
        let url = URL(fileURLWithPath: path)
        return try load(url: url)
    }

    /// Load a circuit from a URL.
    ///
    /// - Parameter url: URL pointing to compiled circuit JSON file.
    /// - Throws: ``VerityError/invalidInput(_:)`` if the file cannot be read.
    public static func load(url: URL) throws -> Circuit {
        do {
            let data = try Data(contentsOf: url)
            return Circuit(data: data, sourcePath: url.path)
        } catch {
            throw VerityError.invalidInput("failed to read circuit at \(url.path): \(error.localizedDescription)")
        }
    }

    /// Resolve to a file path for the FFI layer.
    /// Returns the original path if loaded from a file, or writes to a temp file.
    internal func resolvePath() throws -> (path: String, isTemporary: Bool) {
        if let sourcePath { return (sourcePath, false) }
        return (try writeToTempFile(), true)
    }

    /// Write the circuit JSON to a temporary file for the FFI layer.
    private func writeToTempFile() throws -> String {
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "verity_circuit_\(UUID().uuidString).json"
        let url = URL(fileURLWithPath: path)
        do {
            try data.write(to: url)
        } catch {
            throw VerityError.invalidInput("failed to write temporary circuit file: \(error.localizedDescription)")
        }
        return path
    }
}
