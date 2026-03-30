import Foundation
import Verity

actor VerityService {
    func generateAndVerify(circuit: Circuit, backend: Backend) async throws -> ProofResult {
        // Get resource paths
        let circuitPath = resourcePath(circuit.assetDir, "circuit.json")
        let inputPath = resourcePath(circuit.assetDir, "Prover.toml")

        let verity = try Verity(backend: backend)

        // Prepare
        let prepareStart = CFAbsoluteTimeGetCurrent()
        let scheme: PreparedScheme
        if backend == .provekit, let pkpPath = optionalResourcePath(circuit.assetDir, "prover.pkp"),
           let pkvPath = optionalResourcePath(circuit.assetDir, "verifier.pkv") {
            let prover = try verity.loadProver(from: pkpPath)
            let verifier = try verity.loadVerifier(from: pkvPath)
            scheme = PreparedScheme(prover: prover, verifier: verifier)
        } else {
            scheme = try verity.prepare(circuit: circuitPath)
        }
        let prepareTime = CFAbsoluteTimeGetCurrent() - prepareStart

        // Prove
        let proveStart = CFAbsoluteTimeGetCurrent()
        let proof = try verity.prove(with: scheme.prover, input: inputPath)
        let proveTime = CFAbsoluteTimeGetCurrent() - proveStart

        // Verify
        let verifyStart = CFAbsoluteTimeGetCurrent()
        let isValid = try verity.verify(with: scheme.verifier, proof: proof)
        let verifyTime = CFAbsoluteTimeGetCurrent() - verifyStart

        return ProofResult(
            circuit: circuit, backend: backend,
            proofBytes: proof,
            prepareTime: prepareTime, proveTime: proveTime, verifyTime: verifyTime,
            isValid: isValid
        )
    }

    private func resourcePath(_ dir: String, _ file: String) -> String {
        Bundle.main.path(forResource: file, ofType: nil, inDirectory: dir) ?? ""
    }

    private func optionalResourcePath(_ dir: String, _ file: String) -> String? {
        Bundle.main.path(forResource: file, ofType: nil, inDirectory: dir)
    }
}
