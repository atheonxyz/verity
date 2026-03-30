import SwiftUI
import Verity

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CircuitListView()
                .navigationTitle("Verity Demo")
        }
    }
}
