import Foundation

/// Witness values — the private inputs to a zero-knowledge proof.
///
/// Load from a TOML file (output of `nargo execute`) or construct from a dictionary.
///
/// ```swift
/// let witness = try Witness.load(from: "Prover.toml")
/// let witness = Witness(values: ["x": "5", "y": "10"])
/// let proof   = try scheme.prover.prove(witness: witness)
/// ```
public struct Witness: Sendable {

    internal enum Storage: Sendable {
        case toml(path: String)
        case values([String: String])
        case json(String)
    }

    internal let storage: Storage

    /// Create a witness from a dictionary of field element strings.
    ///
    /// Keys are circuit parameter names. Values are field element strings
    /// (e.g., `"5"`, `"0x1a2b..."`, or decimal strings).
    ///
    /// - Parameter values: Map of parameter names to field element strings.
    public init(values: [String: String]) {
        self.storage = .values(values)
    }

    public init(json: String) throws {
        guard !json.isEmpty else {
            throw VerityError.invalidInput("JSON string cannot be empty")
        }

        let jsonData = Data(json.utf8)
        do {
            let object = try JSONSerialization.jsonObject(with: jsonData)
            guard object is [String: Any] else {
                throw VerityError.invalidInput("witness JSON must be an object")
            }
        } catch let error as VerityError {
            throw error
        } catch {
            throw VerityError.invalidInput("invalid witness JSON: \(error.localizedDescription)")
        }

        self.storage = .json(json)
    }

    /// Load witness values from a TOML file path (e.g., `Prover.toml` from `nargo execute`).
    ///
    /// - Parameter path: Path to the TOML witness file.
    /// - Throws: ``VerityError/invalidInput(_:)`` if the file does not exist.
    public static func load(from path: String) throws -> Witness {
        guard FileManager.default.fileExists(atPath: path) else {
            throw VerityError.invalidInput("witness file not found: \(path)")
        }
        return Witness(tomlPath: path)
    }

    /// Load witness values from a URL.
    ///
    /// - Parameter url: URL pointing to a TOML witness file.
    /// - Throws: ``VerityError/invalidInput(_:)`` if the file does not exist.
    public static func load(url: URL) throws -> Witness {
        try load(from: url.path)
    }

    private init(tomlPath: String) {
        self.storage = .toml(path: tomlPath)
    }

    /// Resolve to FFI-compatible form.
    internal enum Resolved {
        case tomlPath(String)
        case json(String)
    }

    internal func resolve() throws -> Resolved {
        switch storage {
        case .toml(let path):
            return .tomlPath(path)
        case .values(let dict):
            guard !dict.isEmpty else {
                throw VerityError.invalidInput("witness values cannot be empty")
            }
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw VerityError.serializationError
            }
            return .json(jsonString)
        case .json(let json):
            return .json(json)
        }
    }
}
