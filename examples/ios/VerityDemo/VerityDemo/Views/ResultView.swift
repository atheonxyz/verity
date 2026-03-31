import SwiftUI

struct ResultView: View {
    let result: ProofResult

    var body: some View {
        VStack(spacing: 16) {
            validitySection
            timingSection
            memorySection
            proofSection
        }
    }

    // MARK: - Validity

    private var validitySection: some View {
        GroupBox {
            HStack {
                Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(result.isValid ? .green : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isValid ? "Proof Valid" : "Proof Invalid")
                        .font(.headline)
                    Text(formatBytes(result.proofSize))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(result.backend.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(result.isValid ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Timing

    private var timingSection: some View {
        GroupBox("Timing") {
            VStack(spacing: 8) {
                timingRow("Prepare", result.prepareTime,
                          note: result.usedPrecompiled ? "pre-compiled" : nil)
                timingRow("Prove", result.proveTime)
                timingRow("Verify", result.verifyTime)
                Divider()
                timingRow("Total", result.totalTime)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Memory

    private var memorySection: some View {
        GroupBox("Memory") {
            VStack(spacing: 8) {
                metricRow("Process (before)",
                          String(format: "%.1f MB", result.memoryBefore.processMemoryMB))
                metricRow("Process (after)",
                          String(format: "%.1f MB", result.memoryAfter.processMemoryMB))
                metricRow("Delta",
                          String(format: "%+.1f MB", result.memoryDeltaMB))

                if let peak = result.memoryAfter.proveKitPeakRAM {
                    Divider()
                    metricRow("ProveKit peak RAM", formatBytes(Int(peak)))
                }
                if let ram = result.memoryAfter.proveKitRAM {
                    metricRow("ProveKit RAM", formatBytes(Int(ram)))
                }
                if let swap = result.memoryAfter.proveKitSwap, swap > 0 {
                    metricRow("ProveKit swap", formatBytes(Int(swap)))
                }
            }
        }
    }

    // MARK: - Proof Hex

    private var proofSection: some View {
        GroupBox("Proof") {
            Text(result.proofHex)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Row Helpers

    private func timingRow(_ label: String, _ time: TimeInterval, note: String? = nil) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(formatTime(time))
                .font(.body.monospaced())
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
        }
    }
}
