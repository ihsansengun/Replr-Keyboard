import SwiftUI

/// "Where do you need better replies?" — multi-select cards. The primary (first) pick seeds
/// the starting tone + an About You hint via OnboardingSurvey.apply.
struct PersonalizationSurveyStep: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var selected: [String] = []   // ordered; first = primary pick

    var body: some View {
        OnboardingStep(
            step: step, totalSteps: totalSteps,
            sectionLabel: "Personalize",
            headline: "Where do you need better replies?",
            bodyText: "Pick what fits — we'll set your starting tone. You can change it anytime.",
            onBack: onBack
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingSurvey.options) { option in
                    card(option)
                }
            }
        } cta: {
            PrimaryButton(label: selected.isEmpty ? "Skip →" : "Continue →") {
                OnboardingSurvey.apply(selected)
                onNext()
            }
        }
    }

    private func card(_ opt: OnboardingSurvey.Option) -> some View {
        let isOn = selected.contains(opt.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { toggle(opt.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: opt.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isOn ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    .frame(width: 24)
                Text(opt.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(isOn ? ReplrTheme.Color.accentSoft : ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(isOn ? ReplrTheme.Color.accent : ReplrTheme.Color.glassBorder,
                            lineWidth: isOn ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: String) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i) } else { selected.append(id) }
    }
}
