import SwiftUI

/// A segmented top progress bar for the onboarding setup steps:
/// `current` filled capsules out of `total`. Animates as `current` changes.
struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < current
                          ? ReplrTheme.Color.accent
                          : ReplrTheme.Color.textSecondary.opacity(0.22))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
    }
}

#Preview("Progress — light") {
    VStack(spacing: 24) {
        OnboardingProgressBar(current: 1, total: 4)
        OnboardingProgressBar(current: 2, total: 4)
        OnboardingProgressBar(current: 4, total: 4)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReplrTheme.Color.bg)
}
