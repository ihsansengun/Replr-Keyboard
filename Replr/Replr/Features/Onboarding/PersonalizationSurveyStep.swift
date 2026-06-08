import SwiftUI

/// "A bit about you" — gender, age range, optional free-text.
/// All three compose into AppGroupService.aboutUser which ships as
/// "ABOUT THE USER YOU'RE WRITING FOR" in every LLM system prompt.
///
/// Layout: custom scrollable view (not OnboardingStep) so the keyboard
/// never covers content. CTA is pinned via safeAreaInset; a keyboard
/// toolbar "Done" button always lets the user close the keyboard.
struct PersonalizationSurveyStep: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // ── Options ───────────────────────────────────────────────────────
    private let genderOptions = ["Man", "Woman", "Non-binary", "Prefer not to say"]
    private let ageOptions    = ["Under 25", "25–34", "35–44", "45+"]

    @State private var genderSelected: String? = nil
    @State private var ageSelected: String?    = nil
    @State private var aboutText               = ""
    @FocusState private var fieldFocused: Bool

    private var hasAnyInput: Bool {
        genderSelected != nil
            || ageSelected != nil
            || !aboutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ── Body ──────────────────────────────────────────────────────────
    var body: some View {
        ZStack(alignment: .top) {
            ReplrTheme.Color.bg.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Reserve space under the pinned header
                        Color.clear.frame(height: 78)

                        VStack(alignment: .leading, spacing: 28) {
                            titleBlock
                            genderBlock
                            ageBlock
                            aboutBlock
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: fieldFocused) { focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.28)) {
                        proxy.scrollTo("aboutField", anchor: .bottom)
                    }
                }
            }

            // Pinned header
            pinnedHeader
        }
        // CTA always above the keyboard
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(label: hasAnyInput ? "Continue →" : "Skip →") {
                saveAndContinue()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .background(ReplrTheme.Color.bg)
        }
        // "Done" button above the keyboard — the only reliable way to dismiss it
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { fieldFocused = false }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.accent)
            }
        }
    }

    // MARK: - Pinned header (replicates OnboardingStep exactly)

    private var pinnedHeader: some View {
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
        }
    }

    // MARK: - Gender

    private var genderBlock: some View {
        questionBlock(label: "Gender", options: genderOptions,
                      selected: $genderSelected)
    }

    // MARK: - Age range

    private var ageBlock: some View {
        questionBlock(label: "Age range", options: ageOptions,
                      selected: $ageSelected)
    }

    private func questionBlock(label: String,
                               options: [String],
                               selected: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.textSecondary)

            VStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    selectRow(opt,
                              isOn: selected.wrappedValue == opt,
                              action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected.wrappedValue =
                                selected.wrappedValue == opt ? nil : opt
                        }
                    })
                }
            }
        }
    }

    // MARK: - About you

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About you")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.textSecondary)

            // TextEditor with manual placeholder so text never truncates
            ZStack(alignment: .topLeading) {
                if aboutText.isEmpty {
                    Text("e.g. into fitness, keep texts short, use humour…")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                        .padding(.top, 12)
                        .padding(.horizontal, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $aboutText)
                    .font(ReplrTheme.Font.callout)
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($fieldFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: 92)
            }
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
            .id("aboutField")
        }
    }

    // MARK: - Shared row

    private func selectRow(_ label: String,
                           isOn: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isOn ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(isOn ? ReplrTheme.Color.accentSoft : ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        isOn ? ReplrTheme.Color.accent : ReplrTheme.Color.glassBorder,
                        lineWidth: isOn ? 1.5 : 1
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
        if let g = genderSelected, g != "Prefer not to say" {
            parts.append("Gender: \(g).")
        }
        if let a = ageSelected {
            parts.append("Age: \(a).")
        }
        let typed = aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { parts.append(typed) }

        if !parts.isEmpty {
            AppGroupService.shared.aboutUser = parts.joined(separator: " ")
        }
        onNext()
    }
}
