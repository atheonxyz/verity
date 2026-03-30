import SwiftUI
import Verity

struct ProveView: View {
    let circuit: Circuit

    @State private var selectedBackend: Backend = .provekit
    @State private var result: ProofResult?
    @State private var isRunning = false
    @State private var error: String?

    private let service = VerityService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Backend picker
                Picker("Backend", selection: $selectedBackend) {
                    Text("ProveKit").tag(Backend.provekit)
                    Text("Barretenberg").tag(Backend.barretenberg)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBackend) { _, _ in
                    result = nil
                    error = nil
                }

                // Action button
                Button(action: run) {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isRunning ? "Generating..." : "Generate Proof")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)

                // Error
                if let error {
                    GroupBox {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Result
                if let result {
                    ResultView(result: result)
                }
            }
            .padding()
        }
        .navigationTitle(circuit.name)
    }

    private func run() {
        isRunning = true
        error = nil
        result = nil

        Task {
            do {
                let r = try await service.generateAndVerify(
                    circuit: circuit, backend: selectedBackend
                )
                await MainActor.run {
                    result = r
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}
