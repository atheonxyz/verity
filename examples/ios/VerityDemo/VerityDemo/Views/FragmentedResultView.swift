import SwiftUI

struct FragmentedResultView: View {
    let steps: [StepResult]

    private var allValid: Bool { steps.allSatisfy(\.isValid) }
    private var totalLoad: TimeInterval { steps.reduce(0) { $0 + $1.loadTime } }
    private var totalProve: TimeInterval { steps.reduce(0) { $0 + $1.proveTime } }
    private var totalVerify: TimeInterval { steps.reduce(0) { $0 + $1.verifyTime } }
    private var totalTime: TimeInterval { steps.reduce(0) { $0 + $1.totalTime } }
    private var totalProofBytes: Int { steps.reduce(0) { $0 + $1.proofSize } }

    var body: some View {
        VStack(spacing: 16) {
            // Validity banner
            HStack {
                Image(systemName: allValid ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .foregroundStyle(allValid ? .green : .red)
                Text(allValid ? "All \(steps.count) proofs valid" : "Chain invalid")
                    .font(.headline)
            }

            // Per-step breakdown
            GroupBox("Step Breakdown") {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Step").font(.caption2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Load").font(.caption2.bold()).frame(width: 55, alignment: .trailing)
                        Text("Prove").font(.caption2.bold()).frame(width: 55, alignment: .trailing)
                        Text("Verify").font(.caption2.bold()).frame(width: 55, alignment: .trailing)
                        Text("Proof").font(.caption2.bold()).frame(width: 50, alignment: .trailing)
                    }
                    .padding(.bottom, 6)

                    Divider()

                    ForEach(steps) { step in
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: step.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(step.isValid ? .green : .red)
                                    .font(.caption2)
                                Text(shortName(step.name))
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formatTime(step.loadTime))
                                .font(.caption.monospaced())
                                .frame(width: 55, alignment: .trailing)
                            Text(formatTime(step.proveTime))
                                .font(.caption.monospaced())
                                .frame(width: 55, alignment: .trailing)
                            Text(formatTime(step.verifyTime))
                                .font(.caption.monospaced())
                                .frame(width: 55, alignment: .trailing)
                            Text(formatBytes(step.proofSize))
                                .font(.caption.monospaced())
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }

                    Divider().padding(.vertical, 4)

                    // Totals
                    HStack {
                        Text("Total").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatTime(totalLoad)).font(.caption.monospaced().bold()).frame(width: 55, alignment: .trailing)
                        Text(formatTime(totalProve)).font(.caption.monospaced().bold()).frame(width: 55, alignment: .trailing)
                        Text(formatTime(totalVerify)).font(.caption.monospaced().bold()).frame(width: 55, alignment: .trailing)
                        Text(formatBytes(totalProofBytes)).font(.caption.monospaced().bold()).frame(width: 50, alignment: .trailing)
                    }
                }
            }

            // Summary
            GroupBox("Summary") {
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Steps", "\(steps.count)")
                    summaryRow("Total Time", formatTime(totalTime))
                    summaryRow("Total Proof", formatBytes(totalProofBytes))
                    summaryRow("Avg per step", formatTime(totalTime / Double(steps.count)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospaced())
        }
    }

    private func shortName(_ name: String) -> String {
        // t_add_dsc_720 → dsc_720
        name.replacingOccurrences(of: "t_add_", with: "")
            .replacingOccurrences(of: "t_", with: "")
    }
}
