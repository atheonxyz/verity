import Foundation
import Verity

actor VerityService {
    func generateAndVerify(circuit: Circuit, backend: Backend) async throws -> ProofResult {
        let circuitPath = resourcePath(circuit.assetDir, "circuit.json")
        let inputPath = resourcePath(circuit.assetDir, "Prover.toml")

        let verity = try Verity(backend: backend)

        // Prepare or load
        let prepareStart = CFAbsoluteTimeGetCurrent()
        let prover: ProverScheme
        let verifier: VerifierScheme

        if backend == .provekit,
           let pkpPath = optionalResourcePath(circuit.assetDir, "prover.pkp"),
           let pkvPath = optionalResourcePath(circuit.assetDir, "verifier.pkv") {
            prover = try verity.loadProver(from: pkpPath)
            verifier = try verity.loadVerifier(from: pkvPath)
        } else {
            let scheme = try verity.prepare(circuit: circuitPath)
            prover = scheme.prover
            verifier = scheme.verifier
        }
        let prepareTime = CFAbsoluteTimeGetCurrent() - prepareStart

        // Prove
        let proveStart = CFAbsoluteTimeGetCurrent()
        let proof = try verity.prove(with: prover, input: inputPath)
        let proveTime = CFAbsoluteTimeGetCurrent() - proveStart

        // Verify
        let verifyStart = CFAbsoluteTimeGetCurrent()
        let isValid = try verity.verify(with: verifier, proof: proof)
        let verifyTime = CFAbsoluteTimeGetCurrent() - verifyStart

        return ProofResult(
            circuit: circuit, backend: backend,
            proofBytes: proof,
            prepareTime: prepareTime, proveTime: proveTime, verifyTime: verifyTime,
            isValid: isValid
        )
    }

    private func resourcePath(_ dir: String, _ file: String) -> String {
        guard let url = Bundle.main.url(forResource: "Resources", withExtension: nil) else {
            return ""
        }
        return url.appendingPathComponent(dir).appendingPathComponent(file).path
    }

    private func optionalResourcePath(_ dir: String, _ file: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Resources", withExtension: nil) else {
            return nil
        }
        let path = url.appendingPathComponent(dir).appendingPathComponent(file).path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
