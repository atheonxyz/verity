import SwiftUI

struct CircuitListView: View {
    var body: some View {
        List(bundledCircuits) { circuit in
            NavigationLink(destination: ProveView(circuit: circuit)) {
                HStack(spacing: 12) {
                    Image(systemName: circuit.isFragmented ? "link.circle.fill" : "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(circuit.isFragmented ? .orange : .blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(circuit.name)
                            .font(.subheadline.weight(.semibold))
                        Text(circuit.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.insetGrouped)
    }
}
