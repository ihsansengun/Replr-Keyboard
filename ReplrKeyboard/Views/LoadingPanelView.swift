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
            KeyboardHeader(model: model, isToneDimmed: true)

            // Skeleton card — same shape/position as the reply card in RepliesPanelView
            skeletonCard
                .padding(.horizontal, 10)
                .padding(.vertical, 10)

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

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonLine(fraction: 0.92, pulse: false)
            SkeletonLine(fraction: 1.00, pulse: true)
            SkeletonLine(fraction: 0.75, pulse: false)
            SkeletonLine(fraction: 0.88, pulse: true)
            SkeletonLine(fraction: 0.55, pulse: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
        .elevatedSurface(.level1)
    }
}
