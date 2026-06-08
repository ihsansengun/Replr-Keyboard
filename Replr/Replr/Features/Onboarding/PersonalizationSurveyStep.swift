import SwiftUI

/// "A bit about you" — collects pronouns, age range, and an optional free-text blurb.
/// All three fields feed into AppGroupService.aboutUser which ships with every LLM call
/// as "ABOUT THE USER YOU'RE WRITING FOR" in the system prompt.
///
/// Uses its own scrollable layout (not OnboardingStep) so the keyboard never
/// covers the text field: ScrollView auto-scrolls to the focused field, and the
/// CTA button is pinned above the keyboard via safeAreaInset.
struct PersonalizationSurveyStep: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // ── Data ─────────────────────────────────────────────────────────────
    private let pronounOptions = ["He/him", "She/her", "They/them"]
    private let ageOptions     = ["Under 25", "25–34", "35–44", "45+"]

    @State private var pronounSelected: String? = nil
    @State private var ageSelected: String?     = nil
    @State private var aboutText                = ""
    @FocusState private var fieldFocused: Bool

    private var hasAnyInput: Bool {
        pronounSelected != nil
            || ageSelected != nil
            || !aboutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ── Body ──────────────────────────────────────────────────────────────
    var body: some View {
        ZStack(alignment: .top) {
            ReplrTheme.Color.bg.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Spacer that sits under the pinned header
                        Color.clear.frame(height: headerHeight)

                        // ── Body content ──────────────────────────────
                        VStack(alignment: .leading, spacing: 28) {
                            titleBlock
                            pronounBlock
                            ageBlock
                            aboutBlock
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: fieldFocused) { focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("aboutField", anchor: .bottom)
                    }
                }
            }

            // Pinned header (sits on top of the scroll content)
            header
        }
        // CTA always above the keyboard
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                PrimaryButton(label: hasAnyInput ? "Continue →" : "Skip →") {
                    saveAndContinue()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
            .background(ReplrTheme.Color.bg)
        }
    }

    // MARK: - Header (pinned above scroll)

    /// Approximate height of the pinned header so the scroll content starts below it.
    private var headerHeight: CGFloat { 80 }

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(String(format: "%02d / %02d", step, totalSteps))
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }
                ReplrMark(size: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= step ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(ReplrTheme.Color.bg)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Badge("Personalize")
            Text("A bit about you.")
                .font(ReplrTheme.Font.serif(28, weight: .bold))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Helps Replr write in your voice. All optional.")
                .font(ReplrTheme.Font.callout)
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pronouns

    private var pronounBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Your pronouns")
            // Three natural-width chips in a single row
            HStack(spacing: 10) {
                ForEach(pronounOptions, id: \.self) { opt in
                    chipView(opt, isOn: pronounSelected == opt) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            pronounSelected = pronounSelected == opt ? nil : opt
                        }
                    }
                }
            }
        }
    }

    // MARK: - Age range

    private var ageBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Your age range")
            // 2 × 2 equal-width grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(ageOptions, id: \.self) { opt in
                    chipView(opt, isOn: ageSelected == opt) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            ageSelected = ageSelected == opt ? nil : opt
                        }
                    }
                }
            }
        }
    }

    // MARK: - About you

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sectionLabel("About you")
                Text("optional")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.accent.opacity(0.8))
            }

            TextField(
                "e.g. keep texts short, use humour, work in design…",
                text: $aboutText,
                axis: .vertical
            )
            .font(ReplrTheme.Font.callout)
            .foregroundColor(ReplrTheme.Color.textPrimary)
            .lineLimit(1...4)           // grows from 1 line up to 4
            .submitLabel(.done)
            .onSubmit { fieldFocused = false }
            .focused($fieldFocused)
            .padding(14)
            .frame(minHeight: 52, alignment: .topLeading)
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        fieldFocused
                            ? ReplrTheme.Color.accent.opacity(0.55)
                            : ReplrTheme.Color.glassBorder,
                        lineWidth: fieldFocused ? 1.5 : 1
                    )
            )
            .id("aboutField")           // anchor for ScrollViewReader
        }
    }

    // MARK: - Shared sub-views

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(ReplrTheme.Font.caption)
            .foregroundColor(ReplrTheme.Color.textTertiary)
    }

    private func chipView(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                        .fill(isOn
                              ? AnyShapeStyle(ReplrTheme.Color.brandGradient)
                              : AnyShapeStyle(ReplrTheme.Color.surfaceRaised))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                        .strokeBorder(
                            isOn ? Color.clear : ReplrTheme.Color.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }

    // MARK: - Save

    private func saveAndContinue() {
        fieldFocused = false

        var parts: [String] = []
        if let p = pronounSelected {
            parts.append("Pronouns: \(p).")
        }
        if let a = ageSelected {
            parts.append("Age: \(a).")
        }
        let typed = aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            parts.append(typed)
        }
        if !parts.isEmpty {
            AppGroupService.shared.aboutUser = parts.joined(separator: " ")
        }

        onNext()
    }
}
