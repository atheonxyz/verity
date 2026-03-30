import SwiftUI
import Verity

struct ContentView: View {
    @State private var status = "Ready"
    @State private var proofHex = ""
    @State private var isRunning = false
    @State private var selectedBackend: Backend = .provekit

    /// Paths — update these to point at your compiled circuit and input file.
    private let circuitPath = Bundle.main.path(forResource: "circuit", ofType: "json") ?? ""
    private let inputPath = Bundle.main.path(forResource: "Prover", ofType: "toml") ?? ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Backend picker
                Picker("Backend", selection: $selectedBackend) {
                    Text("ProveKit").tag(Backend.provekit)
                    Text("Barretenberg").tag(Backend.barretenberg)
                }
                .pickerStyle(.segmented)

                GroupBox("Status") {
                    Text(status)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.callout.monospaced())
                }

                if !proofHex.isEmpty {
                    GroupBox("Proof (\(proofHex.count / 2) bytes)") {
                        Text(proofHex.prefix(120) + "...")
                            .font(.caption.monospaced())
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()

                Button(action: runFlow) {
                    Label("Prepare → Prove → Verify", systemImage: "lock.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }
            .padding()
            .navigationTitle("Verity SDK Example")
        }
    }

    private func runFlow() {
        isRunning = true
        status = "Initializing..."
        proofHex = ""

        let backend = selectedBackend

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let verity = try Verity(backend: backend)

                // 1. Prepare — compile circuit into in-memory schemes
                update("Preparing circuit (\(backend == .provekit ? "ProveKit" : "Barretenberg"))...")
                let scheme = try verity.prepare(circuit: circuitPath)

                // 2. Prove — generate proof from TOML inputs
                update("Generating proof...")
                let proof = try verity.prove(with: scheme.prover, input: inputPath)

                // 3. Verify — check proof against verifier scheme
                update("Verifying proof...")
                let valid = try verity.verify(with: scheme.verifier, proof: proof)

                let hex = proof.map { String(format: "%02x", $0) }.joined()

                DispatchQueue.main.async {
                    proofHex = hex
                    status = valid ? "Proof VALID (\(proof.count) bytes)" : "Proof INVALID"
                    isRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }

    private func update(_ msg: String) {
        DispatchQueue.main.async { status = msg }
    }
}
