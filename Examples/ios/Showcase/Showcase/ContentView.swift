import SwiftUI
import Verity

/// Demonstrates every SDK capability across both backends.
struct ContentView: View {
    @State private var log = ""
    @State private var isRunning = false

    private let circuitPath = Bundle.main.path(forResource: "circuit", ofType: "json") ?? ""
    private let inputPath = Bundle.main.path(forResource: "Prover", ofType: "toml") ?? ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                    Text(log)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                HStack(spacing: 12) {
                    Button("ProveKit") { run(backend: .provekit) }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning)

                    Button("Barretenberg") { run(backend: .barretenberg) }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isRunning)

                    Button("Both") { runBoth() }
                        .buttonStyle(.bordered)
                        .disabled(isRunning)
                }
            }
            .padding()
            .navigationTitle("SDK Showcase")
        }
    }

    private func run(backend: Backend) {
        isRunning = true
        log = ""

        let circuit = circuitPath
        let input = inputPath

        DispatchQueue.global(qos: .userInitiated).async {
            let name = backend == .provekit ? "ProveKit" : "Barretenberg"
            append("=== \(name) Backend ===\n")

            do {
                let verity = try Verity(backend: backend)

                // ── 1. Prepare (in-memory) ──
                append("[1] Preparing circuit...")
                let scheme = try verity.prepare(circuit: circuit)
                append("    Prover + Verifier handles created (no files written)\n")

                // ── 2. Prove with TOML file ──
                append("[2] Proving with TOML file...")
                let proof = try verity.prove(with: scheme.prover, input: input)
                append("    Proof: \(proof.count) bytes\n")

                // ── 3. Verify ──
                append("[3] Verifying...")
                let valid = try verity.verify(with: scheme.verifier, proof: proof)
                append("    Result: \(valid ? "VALID" : "INVALID")\n")

                // ── 4. Prove again (scheme reuse) ──
                append("[4] Proving again (same scheme, reuse test)...")
                let proof2 = try verity.prove(with: scheme.prover, input: input)
                let valid2 = try verity.verify(with: scheme.verifier, proof: proof2)
                append("    Second proof: \(proof2.count) bytes, valid: \(valid2)\n")

                // ── 5. Save + Load round-trip ──
                append("[5] Save → Load round-trip...")
                let tmpDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("showcase_\(name)").path
                try FileManager.default.createDirectory(
                    atPath: tmpDir, withIntermediateDirectories: true)

                let proverPath = tmpDir + "/prover.\(backend == .provekit ? "pkp" : "bbp")"
                let verifierPath = tmpDir + "/verifier.\(backend == .provekit ? "pkv" : "bbv")"

                try scheme.prover.save(to: proverPath)
                try scheme.verifier.save(to: verifierPath)
                append("    Saved to \(tmpDir)")

                let loadedProver = try verity.loadProver(from: proverPath)
                let loadedVerifier = try verity.loadVerifier(from: verifierPath)

                let proof3 = try verity.prove(with: loadedProver, input: input)
                let valid3 = try verity.verify(with: loadedVerifier, proof: proof3)
                append("    Load → Prove → Verify: \(valid3 ? "VALID" : "INVALID")\n")

                // ── 6. Serialize → Load bytes round-trip ──
                append("[6] Serialize → Load bytes round-trip...")
                let proverBytes = try scheme.prover.serialize()
                let verifierBytes = try scheme.verifier.serialize()
                append("    Prover: \(proverBytes.count) bytes, Verifier: \(verifierBytes.count) bytes")

                let restoredProver = try verity.loadProver(data: proverBytes)
                let restoredVerifier = try verity.loadVerifier(data: verifierBytes)

                let proof4 = try verity.prove(with: restoredProver, input: input)
                let valid4 = try verity.verify(with: restoredVerifier, proof: proof4)
                append("    Bytes → Load → Prove → Verify: \(valid4 ? "VALID" : "INVALID")\n")

                append("=== \(name) DONE ===")
            } catch {
                append("ERROR: \(error.localizedDescription)")
            }

            DispatchQueue.main.async { isRunning = false }
        }
    }

    private func runBoth() {
        isRunning = true
        log = ""

        let circuit = circuitPath
        let input = inputPath

        DispatchQueue.global(qos: .userInitiated).async {
            for backend: Backend in [.provekit, .barretenberg] {
                let name = backend == .provekit ? "ProveKit" : "Barretenberg"
                append("=== \(name) ===")

                do {
                    let verity = try Verity(backend: backend)
                    let scheme = try verity.prepare(circuit: circuit)
                    let proof = try verity.prove(with: scheme.prover, input: input)
                    let valid = try verity.verify(with: scheme.verifier, proof: proof)
                    append("  Proof: \(proof.count) bytes → \(valid ? "VALID" : "INVALID")\n")
                } catch {
                    append("  ERROR: \(error.localizedDescription)\n")
                }
            }

            append("=== Comparison complete ===")
            DispatchQueue.main.async { isRunning = false }
        }
    }

    private func append(_ msg: String) {
        DispatchQueue.main.async { log += msg + "\n" }
    }
}
