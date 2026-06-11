import SwiftUI

/// Onboarding Back Tap step — pitches "reply anywhere," offers the full setup sheet, and lets
/// the user skip (it stays available in Settings). Skippable by design.
struct BackTapOnboardingStep: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var showSetup = false
    @State private var openedSetup = false

    var body: some View {
        OnboardingStep(
            step: step, totalSteps: totalSteps,
            sectionLabel: "Back Tap · Optional",
            headline: "Reply anywhere, even on profiles.",
            bodyText: "Where the keyboard can't open (dating profiles, other apps), triple-tap the back of your phone to capture the screen and get replies.",
            onBack: onBack
        ) {
            BackTapArt()
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Set up Back Tap →") {
                    openedSetup = true
                    showSetup = true
                }
                TertiaryButton(label: openedSetup ? "Continue →" : "Set up later →") {
                    AppGroupService.shared.backTapSkipped = true
                    onNext()
                }
            }
        }
        .sheet(isPresented: $showSetup) {
            BackTapSetupFullView(isPresented: $showSetup)
        }
    }
}

private struct BackTapArt: View {
    var body: some View {
        ZStack {
            DoodleCircle(color: ReplrTheme.Color.amber, lineWidth: 3)
                .frame(width: 156, height: 100)
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.accent)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}
