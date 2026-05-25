import SwiftUI

struct LoadingPanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isToneDimmed: true)

            // Skeleton card — same shape/position as the reply card in RepliesPanelView
            skeletonCard
                .padding(.horizontal, 10)
                .padding(.vertical, 10)

            Spacer(minLength: 0)

            // Status line
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .tint(ReplrTheme.Color.textSecondary)
                Text("Generating replies…")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
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
        .elevatedSurface(.level1)
    }
}
