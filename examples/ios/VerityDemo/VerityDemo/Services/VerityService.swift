import Foundation
import Verity

actor VerityService {
    func generateAndVerify(circuit: DemoCircuit, backend: Backend) async throws -> ProofResult {
        let prefix = circuit.filePrefix
        let circuitPath = try bundlePath("\(prefix)_circuit", ext: "json")
        let inputPath = try bundlePath("\(prefix)_Prover", ext: "toml")

        let verity = try Verity(backend: backend)

        // Load circuit and witness
        let circuitData = try Circuit.load(from: circuitPath)
        let witness = try Witness.load(from: inputPath)

        // Prepare or load
        let prepareStart = CFAbsoluteTimeGetCurrent()
        let prover: ProverScheme
        let verifier: VerifierScheme

        if backend == .provekit,
           let pkpPath = optionalBundlePath("\(prefix)_prover", ext: "pkp"),
           let pkvPath = optionalBundlePath("\(prefix)_verifier", ext: "pkv") {
            prover = try verity.loadProver(from: pkpPath)
            verifier = try verity.loadVerifier(from: pkvPath)
        } else {
            let scheme = try verity.prepare(circuit: circuitData)
            prover = scheme.prover
            verifier = scheme.verifier
        }
        let prepareTime = CFAbsoluteTimeGetCurrent() - prepareStart

        // Prove
        let proveStart = CFAbsoluteTimeGetCurrent()
        let proof = try prover.prove(witness: witness)
        let proveTime = CFAbsoluteTimeGetCurrent() - proveStart

        // Verify
        let verifyStart = CFAbsoluteTimeGetCurrent()
        let isValid = try verifier.verify(proof: proof)
        let verifyTime = CFAbsoluteTimeGetCurrent() - verifyStart

        return ProofResult(
            circuit: circuit, backend: backend,
            proof: proof,
            prepareTime: prepareTime, proveTime: proveTime, verifyTime: verifyTime,
            isValid: isValid
        )
    }

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
