import SwiftUI
import StoreKit

struct CreditPacksView: View {
    var showCloseButton: Bool = false

    @ObservedObject private var manager = CreditsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if showCloseButton {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                ScrollView {
                    VStack(spacing: 28) {
                        // Hero
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text("✦")
                                    .font(.system(size: 18))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("Get More Replies")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                            }
                            Text("Credits never expire. Use whenever you need.")
                                .font(.system(size: 14))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.top, showCloseButton ? 8 : 40)

                        // Balance chip
                        if manager.balance > 0 || AppGroupService.shared.devMode {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("\(manager.balanceDisplay) credits remaining")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ReplrTheme.Color.accentSubtle)
                            .clipShape(Capsule())
                        }

                        // Pack cards
                        if manager.products.isEmpty {
                            ProgressView()
                                .tint(ReplrTheme.Color.accent)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(manager.products, id: \.id) { product in
                                    PackCard(product: product) {
                                        Task {
                                            do {
                                                try await manager.purchase(product)
                                                errorMessage = nil
                                                if showCloseButton { dismiss() }
                                            } catch {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    }
                                    .disabled(manager.isPurchasing)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(ReplrTheme.Color.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Footer
                        VStack(spacing: 8) {
                            Button("Restore Purchases") { Task { await manager.restore() } }
                                .font(.system(size: 13))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)

                            HStack(spacing: 12) {
                                Link("Terms", destination: URL(string: "https://replr.app/terms")!)
                                Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                                Link("Privacy", destination: URL(string: "https://replr.app/privacy")!)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.load() }
    }
}

private struct PackCard: View {
    let product: Product
    let onBuy: () -> Void

    /// Honest per-pack estimate: each generation costs creditsRequired for the
    /// user's current model (2–15), so "1 credit = 1 reply" was simply false.
    private var subtitle: String {
        let credits = CreditsManager.shared.credits(for: product)
        let cost = max(1, AppGroupService.shared.creditsRequired)
        return "≈\(credits / cost) replies with your current model"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            Spacer()
            Button(action: onBuy) {
                Text(product.displayPrice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
    }
}
