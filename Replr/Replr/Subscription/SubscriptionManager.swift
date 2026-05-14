import StoreKit
import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPremium = false
    @Published var products: [Product] = []

    private let productIDs = [
        "Theory-of-Web.Replr.premium.monthly",
        "Theory-of-Web.Replr.premium.yearly",
    ]

    func load() async {
        do {
            products = try await Product.products(for: productIDs)
            await checkEntitlement()
        } catch {
            print("StoreKit load error:", error)
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified = verification else { return }
            await checkEntitlement()
        default: break
        }
    }

    func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID) {
                isPremium = true
                return
            }
        }
        isPremium = false
    }

    func currentTransactionID() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID) {
                return String(transaction.id)
            }
        }
        return nil
    }
}
