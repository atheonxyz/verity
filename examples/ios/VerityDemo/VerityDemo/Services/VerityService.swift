import Foundation
import Verity
import Darwin

actor VerityService {

    typealias PhaseCallback = @Sendable (ProofPhase) -> Void
    typealias PhaseLogCallback = @Sendable (PhaseLogEntry) -> Void

    func generateAndVerify(
        circuit: DemoCircuit,
        backend: Backend,
        onPhase: PhaseCallback? = nil,
        onPhaseComplete: PhaseLogCallback? = nil
    ) async throws -> ProofResult {
        let prefix = circuit.filePrefix
        let inputPath = try bundlePath("\(prefix)_Prover", ext: "toml")

        let verity = try Verity(backend: backend)
        let witness = try Witness.load(from: inputPath)

        let memoryBefore = snapshot(backend: backend)
        var phases: [PhaseLogEntry] = []

        // --- Load ---
        let loadStart = CFAbsoluteTimeGetCurrent()
        onPhase?(.loading)
        let pkpPath = try bundlePath("\(prefix)_prover", ext: "pkp")
        let pkvPath = try bundlePath("\(prefix)_verifier", ext: "pkv")
        let prover = try verity.loadProver(from: pkpPath)
        let verifier = try verity.loadVerifier(from: pkvPath)
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
        let loadEntry = PhaseLogEntry(phase: .loading, duration: loadTime, memoryAfter: snapshot(backend: backend))
        phases.append(loadEntry)
        onPhaseComplete?(loadEntry)

        // --- Prove ---
        onPhase?(.proving)
        let proveStart = CFAbsoluteTimeGetCurrent()
        let proof: Proof
        do {
            proof = try prover.prove(witness: witness)
        } catch {
            let msg = (try? Verity.lastErrorMessage(for: backend)) ?? "none"
            throw VerityError.invalidInput("prove() failed: \(error) | backend msg: \(msg)")
        }
        let proveTime = CFAbsoluteTimeGetCurrent() - proveStart
        let proveEntry = PhaseLogEntry(phase: .proving, duration: proveTime, memoryAfter: snapshot(backend: backend))
        phases.append(proveEntry)
        onPhaseComplete?(proveEntry)

        // --- Verify ---
        onPhase?(.verifying)
        let verifyStart = CFAbsoluteTimeGetCurrent()
        let isValid: Bool
        do {
            isValid = try verifier.verify(proof: proof)
        } catch {
            let msg = (try? Verity.lastErrorMessage(for: backend)) ?? "none"
            throw VerityError.invalidInput("verify() failed: \(error) | backend msg: \(msg)")
        }
        let verifyTime = CFAbsoluteTimeGetCurrent() - verifyStart
        let verifyEntry = PhaseLogEntry(phase: .verifying, duration: verifyTime, memoryAfter: snapshot(backend: backend))
        phases.append(verifyEntry)
        onPhaseComplete?(verifyEntry)

        onPhase?(.done)

        return ProofResult(
            circuit: circuit, backend: backend,
            proof: proof,
            loadTime: loadTime, proveTime: proveTime, verifyTime: verifyTime,
            isValid: isValid,
            memoryBefore: memoryBefore,
            memoryAfter: snapshot(backend: backend),
            phases: phases
        )
    }

    // MARK: - Fragmented Proof Generation

    func generateAndVerifyFragmented(
        circuit: DemoCircuit,
        backend: Backend,
        onPhase: PhaseCallback? = nil,
        onPhaseComplete: PhaseLogCallback? = nil
    ) async throws -> (steps: [StepResult], phases: [PhaseLogEntry], memoryBefore: MemorySnapshot, memoryAfter: MemorySnapshot) {
        guard let stepNames = circuit.steps else {
            throw VerityError.invalidInput("Circuit is not fragmented")
        }

        let verity = try Verity(backend: backend)
        let memoryBefore = snapshot(backend: backend)
        var stepResults: [StepResult] = []
        var phases: [PhaseLogEntry] = []

        for (index, step) in stepNames.enumerated() {
            let label = "Step \(index + 1)/\(stepNames.count): \(step)"

            // --- Load ---
            let loadStart = CFAbsoluteTimeGetCurrent()
            let prover: ProverScheme
            let verifier: VerifierScheme

            onPhase?(.loading)
            let pkpPath = try bundlePath("\(step)_prover", ext: "pkp")
            let pkvPath = try bundlePath("\(step)_verifier", ext: "pkv")
            prover = try verity.loadProver(from: pkpPath)
            verifier = try verity.loadVerifier(from: pkvPath)
            let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
            let loadEntry = PhaseLogEntry(phase: .loading, duration: loadTime, memoryAfter: snapshot(backend: backend), stepName: step)
            phases.append(loadEntry)
            onPhaseComplete?(loadEntry)

            // --- Prove ---
            onPhase?(.proving)
            let inputPath = try bundlePath("\(step)_Prover", ext: "toml")
            let witness = try Witness.load(from: inputPath)
            let proveStart = CFAbsoluteTimeGetCurrent()
            let proof = try prover.prove(witness: witness)
            let proveTime = CFAbsoluteTimeGetCurrent() - proveStart
            let proveEntry = PhaseLogEntry(phase: .proving, duration: proveTime, memoryAfter: snapshot(backend: backend), stepName: step)
            phases.append(proveEntry)
            onPhaseComplete?(proveEntry)

            // --- Verify ---
            onPhase?(.verifying)
            let verifyStart = CFAbsoluteTimeGetCurrent()
            let isValid = try verifier.verify(proof: proof)
            let verifyTime = CFAbsoluteTimeGetCurrent() - verifyStart
            let verifyEntry = PhaseLogEntry(phase: .verifying, duration: verifyTime, memoryAfter: snapshot(backend: backend), stepName: step)
            phases.append(verifyEntry)
            onPhaseComplete?(verifyEntry)

            stepResults.append(StepResult(
                name: step, loadTime: loadTime, proveTime: proveTime,
                verifyTime: verifyTime, isValid: isValid, proofSize: proof.size
            ))
        }

        onPhase?(.done)
        return (stepResults, phases, memoryBefore, snapshot(backend: backend))
    }

    // MARK: - Memory

    private func snapshot(backend: Backend) -> MemorySnapshot {
        var pkRAM: UInt?
        var pkSwap: UInt?
        var pkPeak: UInt?
        if backend == .provekit, let stats = try? Verity.memoryStats() {
            pkRAM = stats.ramUsed
            pkSwap = stats.swapUsed
            pkPeak = stats.peakRam
        }
        return MemorySnapshot(
            processMemoryMB: Self.processMemoryMB(),
            proveKitRAM: pkRAM,
            proveKitSwap: pkSwap,
            proveKitPeakRAM: pkPeak
        )
    }

    private static func processMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / (1024 * 1024) : 0
    }

    // MARK: - Bundle Helpers

    private func bundlePath(_ name: String, ext: String) throws -> String {
        guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
            throw VerityError.invalidInput("bundled resource not found: \(name).\(ext)")
        }
        return path
    }

}
