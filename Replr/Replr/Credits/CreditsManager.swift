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

    private var transactionListener: Task<Void, Never>?

    private init() {
        migrateIfNeeded()
        balance = AppGroupService.shared.effectiveCreditBalance
        startTransactionListener()
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
            await applyGrant(for: transaction, jws: verification.jwsRepresentation)
        case .userCancelled, .pending:
            // .pending (Ask to Buy, SCA) completes later via Transaction.updates.
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

    // MARK: - Transaction safety net

    /// Replays unfinished transactions, then listens for updates for the app's
    /// lifetime. Catches everything `purchase()` can miss: Ask to Buy approvals,
    /// network drops mid-purchase, the app being killed before `finish()`, and
    /// failed server redeems (left unfinished on purpose so they're redelivered).
    private func startTransactionListener() {
        transactionListener = Task.detached(priority: .background) { [weak self] in
            for await pending in Transaction.unfinished {
                await self?.handle(pending)
            }
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    @MainActor
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard productIDs.contains(transaction.productID) else {
            await transaction.finish()
            return
        }
        await applyGrant(for: transaction, jws: result.jwsRepresentation)
    }

    /// Grants a purchase. Signed in → server redeem (authoritative, deduped by
    /// transactionId in the ledger, so re-sending the same transaction is safe).
    /// Not signed in → local fallback grant, deduped via grantedTransactionIDs.
    /// Server unreachable → leave the transaction UNFINISHED so StoreKit
    /// redelivers it and the listener retries later.
    @MainActor
    private func applyGrant(for transaction: Transaction, jws: String) async {
        do {
            let serverBalance = try await CreditsService.redeem(jws: jws)
            AppGroupService.shared.creditBalance = serverBalance
            balance = AppGroupService.shared.effectiveCreditBalance
            await transaction.finish()
        } catch CreditsService.CreditsError.notSignedIn {
            let txID = String(transaction.id)
            guard !AppGroupService.shared.grantedTransactionIDs.contains(txID) else {
                await transaction.finish()
                return
            }
            AppGroupService.shared.creditBalance += creditsForProductID(transaction.productID)
            AppGroupService.shared.recordGrantedTransactionID(txID)
            balance = AppGroupService.shared.effectiveCreditBalance
            await transaction.finish()
        } catch {
            NSLog("[Credits] redeem failed (will retry via Transaction.updates): %@",
                  String(describing: error))
        }
    }

    // MARK: - Server sync

    /// One-time adoption of the local balance into the server ledger. Idempotent
    /// server-side; the flag only avoids redundant calls. Reset on sign-out.
    @MainActor
    func serverMigrateIfNeeded() async {
        guard !AppGroupService.shared.serverCreditsMigrated else { return }
        do {
            let serverBalance = try await CreditsService.migrate(
                claimedBalance: AppGroupService.shared.creditBalance)
            AppGroupService.shared.creditBalance = serverBalance
            AppGroupService.shared.serverCreditsMigrated = true
            balance = AppGroupService.shared.effectiveCreditBalance
            NSLog("[Credits] server migration complete. Balance: %d", serverBalance)
        } catch {
            NSLog("[Credits] server migration deferred: %@", String(describing: error))
        }
    }

    /// Mirrors the authoritative server balance into the App Group (where the
    /// keyboard reads it). No-op for legacy users the server doesn't manage.
    @MainActor
    func syncServerBalance() async {
        // try? flattens fetchBalance's Int? — request failures and "not server-managed"
        // both land here as nil, and both mean: leave the local balance alone.
        guard let serverBalance = try? await CreditsService.fetchBalance() else { return }
        AppGroupService.shared.creditBalance = serverBalance
        balance = AppGroupService.shared.effectiveCreditBalance
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

        // Free tier: 10 generations on the default model — matches the keyboard
        // paywall's "Your 10 free replies are up." copy. (History: flat 10 → only
        // 1 Sonnet capture; then 5× ≈ 5 generations; now 10×.)
        let freeStartingCredits = 10 * ReplrModel.defaultModel.creditsPerRequest
        let trialUsed = defaults.integer(forKey: Constants.trialUsedCountKey)
        let remaining = max(0, freeStartingCredits - trialUsed)
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

    /// Credits a pack grants — for UI copy (PackCard subtitle).
    func credits(for product: Product) -> Int {
        creditsForProductID(product.id)
    }

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
