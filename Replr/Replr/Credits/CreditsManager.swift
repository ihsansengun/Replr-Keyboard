import StoreKit
import Foundation
import Combine

final class CreditsManager: ObservableObject {
    static let shared = CreditsManager()

    @Published var balance: Int = 0
    @Published var products: [Product] = []
    @Published var isPurchasing = false

    private let productIDs = [
        "com.ihsan.replr.credits.100",
        "com.ihsan.replr.credits.300",
        "com.ihsan.replr.credits.750",
        "com.ihsan.replr.credits.2500",
    ]

    private init() {
        migrateIfNeeded()
        balance = AppGroupService.shared.effectiveCreditBalance
    }

    // MARK: - StoreKit

    @MainActor
    func load() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            NSLog("[Credits] StoreKit load error: %@", error.localizedDescription)
        }
    }

    @MainActor
    func purchase(_ product: Product) async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return }
            let credits = creditsForProductID(transaction.productID)
            AppGroupService.shared.creditBalance += credits
            balance = AppGroupService.shared.effectiveCreditBalance
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
    }

    // MARK: - Balance

    func deduct(_ credits: Int) {
        guard !AppGroupService.shared.devMode else { return }
        AppGroupService.shared.creditBalance = max(0, AppGroupService.shared.creditBalance - credits)
        DispatchQueue.main.async { [weak self] in
            self?.balance = AppGroupService.shared.creditBalance
        }
    }

    func refreshBalance() {
        DispatchQueue.main.async { [weak self] in
            self?.balance = AppGroupService.shared.effectiveCreditBalance
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)!
        guard !defaults.bool(forKey: Constants.creditsMigratedKey) else { return }

        // Convert remaining trial credits
        let trialUsed = defaults.integer(forKey: Constants.trialUsedCountKey)
        let remaining = max(0, 10 - trialUsed)
        if remaining > 0 {
            AppGroupService.shared.creditBalance += remaining
        }

        // Goodwill: 1,000 credits for existing premium subscribers
        if let txID = defaults.string(forKey: Constants.transactionIDKey), !txID.isEmpty {
            AppGroupService.shared.creditBalance += 1_000
        }

        defaults.set(true, forKey: Constants.creditsMigratedKey)
        defaults.synchronize()
        NSLog("[Credits] Migration complete. Balance: %d", AppGroupService.shared.creditBalance)
    }

    // MARK: - Helpers

    private func creditsForProductID(_ productID: String) -> Int {
        switch productID {
        case "com.ihsan.replr.credits.100":  return 100
        case "com.ihsan.replr.credits.300":  return 300
        case "com.ihsan.replr.credits.750":  return 750
        case "com.ihsan.replr.credits.2500": return 2_500
        default: return 0
        }
    }

    func creditsRequired(for modelID: String) -> Int {
        ReplrModel(apiID: modelID)?.creditsPerRequest ?? 1
    }

    /// Display string for balance: "∞" in dev mode, number otherwise.
    var balanceDisplay: String {
        AppGroupService.shared.devMode ? "∞" : "\(balance)"
    }
}
