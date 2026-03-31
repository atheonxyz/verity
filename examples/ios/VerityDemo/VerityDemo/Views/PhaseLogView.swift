import SwiftUI

struct PhaseLogView: View {
    let entries: [PhaseLogEntry]
    let currentPhase: ProofPhase?

    var body: some View {
        GroupBox("Progress") {
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                        Text(entry.phase.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTime(entry.duration))
                            .font(.subheadline.monospaced())
                        Text(String(format: "%.1f MB", entry.memoryAfter.processMemoryMB))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                if let phase = currentPhase, phase != .done {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("\(phase.rawValue)...")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
}
