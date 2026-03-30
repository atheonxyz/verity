import Foundation
import Verity

struct Circuit: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let filePrefix: String
}

let bundledCircuits = [
    Circuit(name: "Poseidon2", description: "Hash function proof — fast, small circuit", filePrefix: "poseidon2"),
    Circuit(name: "SHA-256", description: "SHA-256 hash proof — medium complexity", filePrefix: "noir_sha256"),
    Circuit(name: "Age Check", description: "Passport age verification — larger circuit", filePrefix: "complete_age_check"),
]

struct ProofResult {
    let circuit: Circuit
    let backend: Backend
    let proofBytes: Data
    let prepareTime: TimeInterval
    let proveTime: TimeInterval
    let verifyTime: TimeInterval
    let isValid: Bool

    var totalTime: TimeInterval { prepareTime + proveTime + verifyTime }
    var proofHex: String { proofBytes.prefix(60).map { String(format: "%02x", $0) }.joined() + "..." }
}
