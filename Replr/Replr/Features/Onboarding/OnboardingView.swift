import SwiftUI
import Photos

// MARK: - Shared step wrapper

private struct OnboardingStep<Content: View, CTA: View>: View {
    let step: Int           // 1-based, 1–5
    let totalSteps: Int     // always 5
    let sectionLabel: String
    let headline: String
    let bodyText: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: back button | centered mark | step counter
            ZStack {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
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

            // Segmented progress bar
            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= step ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // Text block
            VStack(alignment: .leading, spacing: 8) {
                Text(sectionLabel)
                    .font(ReplrTheme.Font.overline)
                    .tracking(1.5)
                    .foregroundColor(ReplrTheme.Color.accent)
                Text(headline)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bodyText)
                    .font(ReplrTheme.Font.callout)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Variable content
            content()
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // CTA area
            VStack(spacing: 12) {
                cta()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
    }
}

// MARK: - Step views

private struct WelcomeStep: View {
    let onNext: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Nav bar row
                HStack {
                    ReplrMark(size: 14)
                    Spacer()
                    Text("Welcome")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Hero content
                VStack(alignment: .leading, spacing: 16) {
                    ReplrMark(size: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("The reply is")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("already written.")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }

                    Text("Triple-tap the back of your phone. Replr reads the chat, drafts the reply, you tap to send.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineSpacing(4)

                    // Badges
                    HStack(spacing: 16) {
                        Label("On-device", systemImage: "lock.shield")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                        Label("4.9 ★", systemImage: "star.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    PrimaryButton(label: "Set it up →", action: onNext)
                    TertiaryButton(label: "I have an account", action: onSignIn)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct AddKeyboardStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingStep(
            step: 1, totalSteps: 5,
            sectionLabel: "Keyboard",
            headline: "Add Replr to iOS.",
            bodyText: "The keyboard is where the replies show up. iOS will ask you to add it from Settings."
        ) {
            // Settings navigation card
            VStack(alignment: .leading, spacing: 0) {
                // Breadcrumb path
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboard", "Keyboards"], id: \.self) { step in
                        if step != "Settings" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Text(step)
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Indented path continuation
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                        Text("Add New")
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                    .padding(.leading, 14)

                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.accent)
                        Text("Replr")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.accent)
                    }
                    .padding(.leading, 28)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)

                Divider()
                    .overlay(ReplrTheme.Color.border)

                // Keyboard preview row
                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    Text("Replr")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("English (US)")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.success)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Open Keyboard Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onNext()
                }
                TertiaryButton(label: "Already added", action: onNext)
            }
        }
    }
}

private struct FullAccessStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 2, totalSteps: 5,
            sectionLabel: "Permissions",
            headline: "Enable Full Access.",
            bodyText: "Lets the keyboard connect to AI. Once in Settings, follow the path below.",
            onBack: onBack
        ) {
            // Navigation path card
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboards", "Replr"], id: \.self) { item in
                        if item != "Settings" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider().overlay(ReplrTheme.Color.border)

                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replr")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Allow Full Access")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ReplrTheme.Color.success)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Open Keyboard Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Done →", action: onNext)
            }
        }
    }
}

private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 5,
            sectionLabel: "Permissions",
            headline: "Allow Photos.",
            bodyText: "Replr reads your latest screenshot. Nothing is stored or uploaded.",
            onBack: onBack
        ) {
            EmptyView()
        } cta: {
            if status == .authorized || status == .limited {
                PrimaryButton(label: "Continue →", action: onNext)
            } else if status == .denied || status == .restricted {
                VStack(spacing: 12) {
                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    TertiaryButton(label: "Skip", action: onNext)
                }
            } else {
                PrimaryButton(label: "Allow Photos →") {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                        DispatchQueue.main.async {
                            status = newStatus
                            if newStatus == .authorized || newStatus == .limited {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onNext() }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct InstallShortcutStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    private let shortcutURL = "https://www.icloud.com/shortcuts/4239b04c8d0d469b905ce6118c5ce706"

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 5,
            sectionLabel: "Shortcut",
            headline: "Install the Shortcut.",
            bodyText: "A small recipe lives in iOS Shortcuts. It takes the screenshot, hands it to Replr, opens the keyboard.",
            onBack: onBack
        ) {
            // Shortcut preview card
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.onAccent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replr Capture")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("4 actions")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

                // Actions list
                VStack(spacing: 0) {
                    ForEach(Array([
                        "Take Screenshot",
                        "Save to Photos",
                        "Open Replr",
                        "Show Keyboard"
                    ].enumerated()), id: \.offset) { idx, action in
                        HStack {
                            Text(String(format: "%02d", idx + 1))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                                .frame(width: 24, alignment: .leading)
                            Text(action)
                                .font(.system(size: 13))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.success)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if idx < 3 {
                            Divider().overlay(ReplrTheme.Color.border).padding(.leading, 52)
                        }
                    }
                }
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Add to Shortcuts →") {
                    if let url = URL(string: shortcutURL) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Already installed →", action: onNext)
            }
        }
    }
}

private struct BackTapStep: View {
    let onNext: () -> Void     // completes onboarding
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 5, totalSteps: 5,
            sectionLabel: "Back Tap",
            headline: "Triple-tap = capture.",
            bodyText: "iOS Back Tap turns a tap on the back of the phone into a Shortcut. Wire triple-tap to Replr Capture.",
            onBack: onBack
        ) {
            // Accessibility navigation card
            VStack(alignment: .leading, spacing: 0) {
                // Breadcrumb path
                HStack(spacing: 4) {
                    ForEach(["Accessibility", "Touch", "Back Tap", "Triple Tap"], id: \.self) { step in
                        if step != "Accessibility" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        let isLast = step == "Triple Tap"
                        Text(step)
                            .font(.system(size: 12, weight: isLast ? .semibold : .regular))
                            .foregroundColor(isLast ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.border)

                // Shortcut action row
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ReplrTheme.Color.accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: "scope")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.onAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replr Capture")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Three taps. The apple, the back, anywhere.")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 10) {
                PrimaryButton(label: "Open Back Tap Settings →") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Done →", action: onNext)
                Text("You can use Double Tap instead of Triple Tap — just choose whichever feels natural.")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Root coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    @AppStorage("onboardingStep") private var step = 0

    var body: some View {
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            case 1:
                AddKeyboardStep(onNext: { step = 2 })
            case 2:
                FullAccessStep(onNext: { step = 3 }, onBack: { step = 1 })
            case 3:
                PhotosPermissionStep(onNext: { step = 4 }, onBack: { step = 2 })
            case 4:
                InstallShortcutStep(onNext: { step = 5 }, onBack: { step = 3 })
            case 5:
                BackTapStep(onNext: { step = 0; onComplete() }, onBack: { step = 4 })
            default:
                WelcomeStep(onNext: { step = 1 }, onSignIn: onSignIn)
            }
        }
        .onAppear {
            if step > 5 { step = 0 }
        }
    }
}

// MARK: - BackTapSetupFullView (deep-link sheet from replr://setup)

struct BackTapSetupFullView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Back Tap")
                            .font(ReplrTheme.Font.overline)
                            .tracking(1.5)
                            .foregroundColor(ReplrTheme.Color.accent)
                        Text("Triple-tap = capture.")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Triple-tapping the back of your iPhone triggers Replr to capture a screenshot and generate replies.")
                            .font(ReplrTheme.Font.callout)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array([
                            "Settings → Accessibility → Touch → Back Tap",
                            "Tap \"Triple Tap\"",
                            "Scroll down and choose Shortcuts → Replr Capture"
                        ].enumerated()), id: \.offset) { idx, text in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundColor(ReplrTheme.Color.onAccent)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(ReplrTheme.Color.accent))
                                Text(text)
                                    .font(ReplrTheme.Font.callout)
                                    .foregroundColor(ReplrTheme.Color.textPrimary)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(16)
                    .background(ReplrTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .stroke(ReplrTheme.Color.border, lineWidth: 1)
                    )

                    Text("First time you triple-tap, iOS will ask to share the screenshot with Replr. Tap \"Allow Always\".")
                        .font(ReplrTheme.Font.footnote)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineSpacing(3)

                    PrimaryButton(label: "Open Settings →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
            .navigationTitle("Set up Back Tap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(ReplrTheme.Color.accent)
                }
            }
        }
    }
}
