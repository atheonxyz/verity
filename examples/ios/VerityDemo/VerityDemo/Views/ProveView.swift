import SwiftUI
import os
import Verity

struct ProveView: View {
    let circuit: DemoCircuit

    @State private var selectedBackend: Backend = .provekit
    @State private var usePrecompiled = true
    @State private var result: ProofResult?
    @State private var isRunning = false
    @State private var error: String?
    @State private var runTask: Task<Void, Never>?
    @State private var currentPhase: ProofPhase?
    @State private var liveLog: [PhaseLogEntry] = []

    @State private var service = VerityService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Backend picker
                Picker("Backend", selection: $selectedBackend) {
                    Text("ProveKit").tag(Backend.provekit)
                    Text("Barretenberg").tag(Backend.barretenberg)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBackend) { _ in
                    result = nil
                    error = nil
                    liveLog = []
                    currentPhase = nil
                }

                // Precompiled toggle
                Toggle("Use Precompiled Schemes", isOn: $usePrecompiled)
                    .font(.subheadline)
                    .tint(.blue)

                // Action button
                Button(action: run) {
                    HStack(spacing: 10) {
                        if isRunning {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)

                // Live progress log
                if !liveLog.isEmpty || (isRunning && currentPhase != nil) {
                    PhaseLogView(entries: liveLog, currentPhase: isRunning ? currentPhase : nil)
                }

                // Error
                if let error {
                    GroupBox {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
        .onDisappear { runTask?.cancel() }
    }

    private var buttonLabel: String {
        guard isRunning else { return "Generate Proof" }
        guard let phase = currentPhase, phase != .done else { return "Starting..." }
        return "\(phase.rawValue)..."
    }

    private func run() {
        isRunning = true
        error = nil
        result = nil
        liveLog = []
        currentPhase = nil

        runTask = Task {
            do {
                let r = try await service.generateAndVerify(
                    circuit: circuit,
                    backend: selectedBackend,
                    usePrecompiled: usePrecompiled,
                    onPhase: { phase in
                        Task { @MainActor in currentPhase = phase }
                    },
                    onPhaseComplete: { entry in
                        Task { @MainActor in liveLog.append(entry) }
                    }
                )
                await MainActor.run {
                    result = r
                    isRunning = false
                }
            } catch {
                os_log("[VerityDemo] ERROR: \(error)")
                if let lastMsg = try? Verity.lastErrorMessage(for: selectedBackend) {
                    os_log("[VerityDemo] lastErrorMessage: \(lastMsg ?? "nil")")
                }
                await MainActor.run {
                    self.error = friendlyError(error)
                    isRunning = false
                }
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let ve = error as? VerityError {
            return ve.errorDescription ?? "\(ve)"
        }
        let msg = error.localizedDescription
        if msg.contains("memory") || msg.contains("alloc") {
            return "Out of memory — try a smaller circuit or configure memory limits with Verity.configureMemory()."
        }
        if msg.contains("not found") || msg.contains("resource") {
            return "Circuit file not found in bundle. Ensure all circuit assets are included."
        }
        return msg
    }
}
