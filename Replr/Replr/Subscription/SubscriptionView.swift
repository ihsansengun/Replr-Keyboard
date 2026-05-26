import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @State private var purchasing = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Premium badge
                if manager.isPremium {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Text("Premium Active")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Spacer()
                    }
                    .padding(16)
                    .background(ReplrTheme.Color.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.accent.opacity(0.35), lineWidth: 1)
                    )
                }

                // Products
                ForEach(manager.products, id: \.id) { product in
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(product.displayName)
                                .font(.system(size: 17, weight: .semibold))
                            Text(product.displayPrice)
                                .font(.system(size: 15))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }

                        Button {
                            purchasing = true
                            Task {
                                do {
                                    try await manager.purchase(product)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                purchasing = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if purchasing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(ReplrTheme.Color.onAccent)
                                        .scaleEffect(0.8)
                                }
                                Text(purchasing ? "Processing…" : "Subscribe")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ReplrTheme.Color.onAccent)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                    .fill(ReplrTheme.Color.accent.opacity(purchasing || manager.isPremium ? 0.35 : 1))
                            )
                            .shadow(color: ReplrTheme.Color.accent.opacity(purchasing || manager.isPremium ? 0 : (scheme == .dark ? 0.55 : 0)), radius: 18, x: 0, y: 6)
                            .shadow(color: .black.opacity(purchasing || manager.isPremium ? 0 : (scheme == .dark ? 0.22 : 0.10)), radius: scheme == .dark ? 6 : 16, x: 0, y: scheme == .dark ? 3 : 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(purchasing || manager.isPremium)
                    }
                    .padding(16)
                    .background(ReplrTheme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
                    )
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(ReplrTheme.Color.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(ReplrTheme.Color.danger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                }
            }
            .padding(20)
        }
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.load() }
    }
}
