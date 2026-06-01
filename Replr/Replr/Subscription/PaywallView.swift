import SwiftUI
import StoreKit

struct PaywallView: View {
    /// false = no dismiss button (arrived from trial exhaustion).
    /// true = show close button (arrived from Settings).
    var showCloseButton: Bool = false

    @StateObject private var manager = SubscriptionManager.shared
    @State private var selectedPlan: PlanOption = .annual
    @State private var purchasing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    enum PlanOption { case monthly, annual }

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
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text("✦")
                                    .font(.system(size: 18))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("Unlock Replr Pro")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                            }
                            Text("Reply smarter. Every time.")
                                .font(.system(size: 15))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.top, showCloseButton ? 8 : 40)

                        // Plan Cards
                        HStack(spacing: 12) {
                            PlanCard(
                                title: "Monthly",
                                price: monthlyPrice,
                                subtitle: "per month",
                                badge: nil,
                                isSelected: selectedPlan == .monthly
                            )
                            .onTapGesture { selectedPlan = .monthly }

                            PlanCard(
                                title: "Annual",
                                price: annualPrice,
                                subtitle: "per year",
                                badge: "Save 50%",
                                isSelected: selectedPlan == .annual
                            )
                            .onTapGesture { selectedPlan = .annual }
                        }
                        .padding(.horizontal, 20)

                        // Feature List
                        VStack(alignment: .leading, spacing: 10) {
                            FeatureRow(text: "5 reply suggestions per capture")
                            FeatureRow(text: "Scroll capture — full conversation context")
                            FeatureRow(text: "Unlimited daily use")
                            FeatureRow(text: "Try Again anytime")
                        }
                        .padding(.horizontal, 24)

                        // CTA
                        VStack(spacing: 12) {
                            Button {
                                purchase()
                            } label: {
                                HStack(spacing: 8) {
                                    if purchasing {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(ReplrTheme.Color.onAccent)
                                            .scaleEffect(0.8)
                                    }
                                    Text(purchasing ? "Processing…"
                                         : "Continue with \(selectedPlan == .annual ? "Annual" : "Monthly")")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(ReplrTheme.Color.onAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                        .fill(ReplrTheme.Color.accent.opacity(purchasing ? 0.5 : 1))
                                )
                                .shadow(
                                    color: ReplrTheme.Color.accent.opacity(scheme == .dark ? 0.55 : 0),
                                    radius: 18, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(purchasing || manager.products.isEmpty)
                            .padding(.horizontal, 20)

                            if selectedPlan == .annual {
                                Button { selectedPlan = .monthly } label: {
                                    Text("Or continue monthly")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(ReplrTheme.Color.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Footer
                        HStack(spacing: 16) {
                            Button("Restore") { restore() }
                            Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                            Link("Terms", destination: URL(string: "https://replr.app/terms")!)
                            Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                            Link("Privacy", destination: URL(string: "https://replr.app/privacy")!)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.load() }
    }

    // MARK: - Helpers

    private var monthlyProduct: Product? {
        manager.products.first { $0.id.contains("monthly") }
    }

    private var annualProduct: Product? {
        manager.products.first { $0.id.contains("yearly") }
    }

    private var monthlyPrice: String {
        monthlyProduct?.displayPrice ?? "$9.99"
    }

    private var annualPrice: String {
        annualProduct?.displayPrice ?? "$59.99"
    }

    private func purchase() {
        let product = selectedPlan == .annual ? annualProduct : monthlyProduct
        guard let product else { return }
        purchasing = true
        errorMessage = nil
        Task {
            do {
                try await manager.purchase(product)
                AppGroupService.shared.paywallRequested = false
                AppGroupService.shared.trialExhausted = false
            } catch {
                errorMessage = error.localizedDescription
            }
            purchasing = false
        }
    }

    private func restore() {
        purchasing = true
        Task {
            try? await AppStore.sync()
            await manager.checkEntitlement()
            if manager.isPremium {
                AppGroupService.shared.paywallRequested = false
                AppGroupService.shared.trialExhausted = false
            }
            purchasing = false
        }
    }
}

// MARK: - Supporting Views

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ReplrTheme.Color.accent))
            } else {
                Spacer().frame(height: 20)
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Text(price)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(ReplrTheme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.glassBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? ReplrTheme.Color.accent.opacity(0.25) : .clear,
            radius: 12, x: 0, y: 4
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.accent)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(ReplrTheme.Color.textPrimary)
            Spacer()
        }
    }
}
