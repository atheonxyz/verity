import Foundation
import Verity
import Darwin

actor VerityService {

    typealias PhaseCallback = @Sendable (ProofPhase) -> Void
    typealias PhaseLogCallback = @Sendable (PhaseLogEntry) -> Void

    func generateAndVerify(
        circuit: DemoCircuit,
        backend: Backend,
        usePrecompiled: Bool = true,
        onPhase: PhaseCallback? = nil,
        onPhaseComplete: PhaseLogCallback? = nil
    ) async throws -> ProofResult {
        let prefix = circuit.filePrefix
        let circuitPath = try bundlePath("\(prefix)_circuit", ext: "json")
        let inputPath = try bundlePath("\(prefix)_Prover", ext: "toml")

        let verity = try Verity(backend: backend)
        let circuitData = try Circuit.load(from: circuitPath)
        let witness = try Witness.load(from: inputPath)

        let memoryBefore = snapshot(backend: backend)
        var phases: [PhaseLogEntry] = []

        // --- Prepare or Load ---
        var prover: ProverScheme
        var verifier: VerifierScheme
        var usedPrecompiled = false
        let prepareStart = CFAbsoluteTimeGetCurrent()

        if usePrecompiled,
           backend == .provekit,
           let pkpPath = optionalBundlePath("\(prefix)_prover", ext: "pkp"),
           let pkvPath = optionalBundlePath("\(prefix)_verifier", ext: "pkv") {
            onPhase?(.loading)
            do {
                prover = try verity.loadProver(from: pkpPath)
                verifier = try verity.loadVerifier(from: pkvPath)
                usedPrecompiled = true
            } catch {
                // Pre-compiled .pkp/.pkv may be stale — compile from scratch
                onPhase?(.preparing)
                let scheme = try verity.prepare(circuit: circuitData)
                prover = scheme.prover
                verifier = scheme.verifier
            }
        } else {
            onPhase?(.preparing)
            let scheme = try verity.prepare(circuit: circuitData)
            prover = scheme.prover
            verifier = scheme.verifier
        }
        let prepareTime = CFAbsoluteTimeGetCurrent() - prepareStart
        let preparePhase: ProofPhase = usedPrecompiled ? .loading : .preparing
        let prepareEntry = PhaseLogEntry(phase: preparePhase, duration: prepareTime, memoryAfter: snapshot(backend: backend))
        phases.append(prepareEntry)
        onPhaseComplete?(prepareEntry)

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
            prepareTime: prepareTime, proveTime: proveTime, verifyTime: verifyTime,
            isValid: isValid,
            usedPrecompiled: usedPrecompiled,
            memoryBefore: memoryBefore,
            memoryAfter: snapshot(backend: backend),
            phases: phases
        )
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

    private func optionalBundlePath(_ name: String, ext: String) -> String? {
        Bundle.main.path(forResource: name, ofType: ext)
    }
}
