import SwiftUI

struct LoadingPanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isToneDimmed: true)
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.55)
                        .tint(KBColors.accent)
                    Text("Generating replies…")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.accent.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    SkeletonLine(fraction: 0.80, pulse: false)
                    SkeletonLine(fraction: 0.95, pulse: true)
                    SkeletonLine(fraction: 0.65, pulse: false)
                }
                .padding(.horizontal, 12)
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.background)
    }
}
