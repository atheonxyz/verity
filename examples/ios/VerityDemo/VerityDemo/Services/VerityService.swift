import Foundation
import Verity

actor VerityService {
    func generateAndVerify(circuit: Circuit, backend: Backend) async throws -> ProofResult {
        let prefix = circuit.filePrefix
        let circuitPath = bundlePath("\(prefix)_circuit", ext: "json")
        let inputPath = bundlePath("\(prefix)_Prover", ext: "toml")

        let verity = try Verity(backend: backend)

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

    private func bundlePath(_ name: String, ext: String) -> String {
        Bundle.main.path(forResource: name, ofType: ext) ?? ""
    }

    private func optionalBundlePath(_ name: String, ext: String) -> String? {
        Bundle.main.path(forResource: name, ofType: ext)
    }
}
