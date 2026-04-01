import Foundation
import Verity

// MARK: - Demo Circuit

struct DemoCircuit: Identifiable, Sendable {
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

// MARK: - Proof Phase

enum ProofPhase: String, Sendable {
    case preparing = "Prepare"
    case loading = "Load"
    case proving = "Prove"
    case verifying = "Verify"
    case done = "Done"
}

// MARK: - Memory Snapshot

struct MemorySnapshot: Sendable {
    let processMemoryMB: Double
    let proveKitRAM: UInt?
    let proveKitSwap: UInt?
    let proveKitPeakRAM: UInt?

    static let zero = MemorySnapshot(processMemoryMB: 0, proveKitRAM: nil, proveKitSwap: nil, proveKitPeakRAM: nil)
}

// MARK: - Phase Log Entry

struct PhaseLogEntry: Identifiable, Sendable {
    let id = UUID()
    let phase: ProofPhase
    let duration: TimeInterval
    let memoryAfter: MemorySnapshot
}

// MARK: - Proof Result

struct ProofResult: Sendable {
    let circuit: DemoCircuit
    let backend: Backend
    let proof: Proof
    let prepareTime: TimeInterval
    let proveTime: TimeInterval
    let verifyTime: TimeInterval
    let isValid: Bool
    let usedPrecompiled: Bool
    let memoryBefore: MemorySnapshot
    let memoryAfter: MemorySnapshot
    let phases: [PhaseLogEntry]

    var totalTime: TimeInterval { prepareTime + proveTime + verifyTime }
    var proofHex: String { proof.hexPreview(maxBytes: 80) }
    var proofSize: Int { proof.size }
    var memoryDeltaMB: Double { memoryAfter.processMemoryMB - memoryBefore.processMemoryMB }
}

// MARK: - Formatting Helpers

func formatTime(_ t: TimeInterval) -> String {
    if t < 0.001 { return "<1ms" }
    if t < 1 { return String(format: "%.0fms", t * 1000) }
    return String(format: "%.2fs", t)
}

func formatBytes(_ bytes: Int) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
}
