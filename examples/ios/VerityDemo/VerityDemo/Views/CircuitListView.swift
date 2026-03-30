import SwiftUI

struct CircuitListView: View {
    var body: some View {
        List(bundledCircuits) { circuit in
            NavigationLink(destination: ProveView(circuit: circuit)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(circuit.name)
                        .font(.headline)
                    Text(circuit.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
