import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @State private var purchasing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if manager.isPremium {
                Section {
                    Label("Premium Active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
            ForEach(manager.products, id: \.id) { product in
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName).font(.headline)
                        Text(product.displayPrice).foregroundStyle(.secondary)
                    }
                    Button("Subscribe") {
                        purchasing = true
                        Task {
                            do {
                                try await manager.purchase(product)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            purchasing = false
                        }
                    }
                    .disabled(purchasing || manager.isPremium)
                }
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Premium")
        .task { await manager.load() }
    }
}
