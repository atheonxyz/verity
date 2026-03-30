import Foundation
import Verity

struct DemoCircuit: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let filePrefix: String
}

let bundledCircuits = [
    DemoCircuit(name: "Poseidon2", description: "Hash function proof — fast, small circuit", filePrefix: "poseidon2"),
    DemoCircuit(name: "SHA-256", description: "SHA-256 hash proof — medium complexity", filePrefix: "noir_sha256"),
    DemoCircuit(name: "Age Check", description: "Passport age verification — larger circuit", filePrefix: "complete_age_check"),
]

struct ProofResult {
    let circuit: DemoCircuit
    let backend: Backend
    let proof: Proof
    let prepareTime: TimeInterval
    let proveTime: TimeInterval
    let verifyTime: TimeInterval
    let isValid: Bool

    var totalTime: TimeInterval { prepareTime + proveTime + verifyTime }
    var proofHex: String { proof.hexPreview(maxBytes: 60) }
    var proofSize: Int { proof.size }
}
