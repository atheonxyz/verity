import SwiftUI

struct ResultView: View {
    let result: ProofResult

    var body: some View {
        VStack(spacing: 16) {
            // Validity badge
            GroupBox {
                HStack {
                    Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(result.isValid ? .green : .red)
                    VStack(alignment: .leading) {
                        Text(result.isValid ? "Proof Valid" : "Proof Invalid")
                            .font(.headline)
                        Text("\(result.proofBytes.count) bytes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // Timing breakdown
            GroupBox("Timing") {
                VStack(spacing: 8) {
                    timingRow("Prepare", result.prepareTime)
                    timingRow("Prove", result.proveTime)
                    timingRow("Verify", result.verifyTime)
                    Divider()
                    timingRow("Total", result.totalTime)
                        .fontWeight(.semibold)
                }
            }

            // Proof preview
            GroupBox("Proof") {
                Text(result.proofHex)
                    .font(.caption.monospaced())
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func timingRow(_ label: String, _ time: TimeInterval) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatTime(time))
                .font(.body.monospaced())
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        if t < 0.001 { return "<1ms" }
        if t < 1 { return String(format: "%.0fms", t * 1000) }
        return String(format: "%.2fs", t)
    }
}
