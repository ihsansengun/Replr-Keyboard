import SwiftUI

/// "How do you come across?" — single-select style grid + optional free-text About You.
/// The style pick seeds the starting tone; the typed text ships with every future LLM call
/// as the user's voice profile (stored in AppGroupService.aboutUser).
struct PersonalizationSurveyStep: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selected: String? = nil
    @State private var aboutText: String = ""
    @FocusState private var fieldFocused: Bool

    private var canContinue: Bool {
        selected != nil || !aboutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingStep(
            step: step, totalSteps: totalSteps,
            sectionLabel: "Personalize",
            headline: "How do you come across?",
            bodyText: "Helps Replr sound like you in every reply.",
            onBack: onBack
        ) {
            VStack(spacing: 16) {

                // ── 2 × 2 style grid ─────────────────────────────────
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(OnboardingSurvey.options) { opt in
                        styleCard(opt)
                    }
                }

                // ── About you (optional free text) ────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("About you (optional)")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)

                    TextField("e.g. 26, in design, keep texts short…", text: $aboutText, axis: .vertical)
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                        .lineLimit(3)
                        .focused($fieldFocused)
                        .padding(12)
                        .background(ReplrTheme.Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                                .strokeBorder(
                                    fieldFocused
                                        ? ReplrTheme.Color.accent.opacity(0.5)
                                        : ReplrTheme.Color.glassBorder,
                                    lineWidth: fieldFocused ? 1.5 : 1
                                )
                        )
                }
            }
        } cta: {
            PrimaryButton(label: canContinue ? "Continue →" : "Skip →") {
                fieldFocused = false

                // 1. Apply tone from style pick (sets tone + fallback hint)
                if let id = selected {
                    OnboardingSurvey.apply([id])
                }

                // 2. User's own words take priority over the style hint
                let typed = aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !typed.isEmpty {
                    AppGroupService.shared.aboutUser = typed
                }

                onNext()
            }
        }
    }

    // MARK: - Style card

    private func styleCard(_ opt: OnboardingSurvey.Option) -> some View {
        let isOn = selected == opt.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                // Tapping the active card deselects it
                selected = selected == opt.id ? nil : opt.id
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: opt.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isOn ? ReplrTheme.Color.onAccent : ReplrTheme.Color.accent)

                Text(opt.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(isOn
                          ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                          : AnyShapeStyle(ReplrTheme.Color.surfaceRaised))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .strokeBorder(isOn ? Color.clear : ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}
