import SwiftUI
import Combine

struct LoadingPanelView: View {
    @ObservedObject var model: KeyboardModel

    // Rotating status — maps to the real pipeline phases so the wait reads as
    // "working" not "stuck". Advances and HOLDS on the last line (never loops back).
    @State private var statusIndex = 0
    private let statuses = [
        "Reading the chat…",
        "Catching the vibe…",
        "Crafting your replies…",
        "Almost there…",
    ]
    private let statusTimer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // isModeHidden: same rationale as RepliesPanelView — saves ~44 px on
            // apps that constrain keyboard height (e.g. WhatsApp).
            KeyboardHeader(model: model, isToneDimmed: true, isModeHidden: true)

            // Skeleton reply cards — preview the shape of the replies that are on the way.
            skeletonCards
                .padding(.horizontal, 10)
                .padding(.top, 10)

            Spacer(minLength: 0)

            // Status line — rotating phase text, cross-fading in place
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .tint(ReplrTheme.Color.textSecondary)
                Text(statuses[statusIndex])
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: statusIndex)
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
        .onReceive(statusTimer) { _ in
            if statusIndex < statuses.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) { statusIndex += 1 }
            }
        }
    }

    private var skeletonCards: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 7) {
                        SkeletonLine(fraction: 0.95, pulse: i == 0)
                        SkeletonLine(fraction: i == 1 ? 0.70 : 0.55, pulse: i == 1)
                    }
                }
                .padding(12)
                .background(ReplrTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                        .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
                )
                .elevatedSurface(.level1)
            }
        }
    }
}
