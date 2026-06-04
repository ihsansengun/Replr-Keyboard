import SwiftUI
import Combine
import Photos

// MARK: - Shared step wrapper

struct OnboardingStep<Content: View, CTA: View>: View {
    let step: Int
    let totalSteps: Int
    let sectionLabel: String
    let headline: String
    let bodyText: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= step ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 8) {
                Badge(sectionLabel)
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

            content()
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                cta()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
    }
}

// MARK: - Step views

private struct WelcomeStep: View {
    let onNext: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text("Welcome")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

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

                    Text("Your conversations are sent to generate replies, then discarded — nothing stored on any server. See Privacy in Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                Spacer()

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
    var onBack: (() -> Void)? = nil
    @State private var detected = AppGroupService.shared.keyboardInstalled

    var body: some View {
        OnboardingStep(
            step: 1, totalSteps: 4,
            sectionLabel: "Keyboard",
            headline: "Add Replr to iOS.",
            bodyText: "The keyboard is where the replies show up. iOS will ask you to add it from Settings.",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(["Settings", "General", "Keyboard", "Keyboards"], id: \.self) { item in
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

                Divider().overlay(ReplrTheme.Color.glassBorder)

                HStack(spacing: 12) {
                    ReplrMark(size: 13)
                    Text("Replr")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Spacer()
                    if detected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ReplrTheme.Color.success)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: detected ? "Keyboard added ✓ — Continue →" : "Open Keyboard Settings →") {
                    if !detected, let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onNext()
                }
                if !detected {
                    TertiaryButton(label: "Already added", action: onNext)
                }
            }
        }
        .onReceive(
            Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
        ) { _ in
            if !detected {
                detected = AppGroupService.shared.keyboardInstalled
                if detected { onNext() }
            }
        }
    }
}

private struct FullAccessStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var detected = AppGroupService.shared.fullAccessGranted
    @AppStorage("onboarding.fullAccessSettingsOpened") private var settingsOpened = false

    var body: some View {
        OnboardingStep(
            step: 2, totalSteps: 4,
            sectionLabel: "Permissions",
            headline: "Enable Full Access.",
            bodyText: "Lets the keyboard connect to AI. Already turned it on? Tap “I've enabled it” — we confirm it the next time you open the Replr keyboard. Otherwise, follow the path below in Settings.",
            onBack: onBack
        ) {
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

                Divider().overlay(ReplrTheme.Color.glassBorder)

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
                    if detected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ReplrTheme.Color.success)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        } cta: {
            if detected {
                PrimaryButton(label: "Full Access enabled ✓ — Continue →", action: onNext)
            } else if settingsOpened {
                VStack(spacing: 12) {
                    PrimaryButton(label: "I've enabled it →", action: onNext)
                    TertiaryButton(label: "Open Settings again →") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    PrimaryButton(label: "Open Keyboard Settings →") {
                        settingsOpened = true
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    TertiaryButton(label: "I've enabled it →", action: onNext)
                }
            }
        }
        .onDisappear { settingsOpened = false }
        .onReceive(
            Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
        ) { _ in
            if !detected {
                detected = AppGroupService.shared.fullAccessGranted
                if detected { onNext() }
            }
        }
    }
}

private struct InstallShortcutStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @AppStorage("onboarding.shortcutOpened") private var shortcutOpened = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 4,
            sectionLabel: "Shortcut",
            headline: "Install the Shortcut.",
            bodyText: "A two-step recipe in iOS Shortcuts takes the screenshot and hands it to Replr — no Photos access needed.",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
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
                        Text("2 actions")
                            .font(.system(size: 11))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(ReplrTheme.Color.glassBorder)

                VStack(spacing: 0) {
                    ForEach(Array(["Take Screenshot", "Generate Reply"].enumerated()), id: \.offset) { idx, action in
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
                        if idx < 1 {
                            Divider().overlay(ReplrTheme.Color.glassBorder).padding(.leading, 52)
                        }
                    }
                }
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        } cta: {
            VStack(spacing: 12) {
                PrimaryButton(label: "Add to Shortcuts →") {
                    shortcutOpened = true
                    if let url = URL(string: Constants.shortcutInstallURL) {
                        UIApplication.shared.open(url)
                    }
                }
                TertiaryButton(label: "Already installed →", action: onNext)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active, shortcutOpened {
                shortcutOpened = false
                onNext()
            }
        }
        .onDisappear { shortcutOpened = false }
    }
}

// MARK: - Photos permission (Phase 2 — screenshot capture)

private struct PhotosPermissionStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Environment(\.scenePhase) private var scenePhase
    private var granted: Bool { status == .authorized || status == .limited }
    private var denied: Bool { status == .denied || status == .restricted }

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 4,
            sectionLabel: "Permissions",
            headline: "Allow Photos.",
            bodyText: "Replr reads the screenshot you take of a chat to draft replies. It only ever reads the one screenshot you capture — nothing else.",
            onBack: onBack
        ) {
            EmptyView()
        } cta: {
            if granted {
                PrimaryButton(label: "Photos allowed ✓ — Continue →", action: onNext)
            } else {
                VStack(spacing: 12) {
                    PrimaryButton(label: denied ? "Open Settings →" : "Allow Photos →") { handleTap() }
                    TertiaryButton(label: "Skip", action: onNext)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            // Re-check on return — catches a grant made in Settings, and refreshes stale state.
            guard phase == .active else { return }
            let fresh = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            status = fresh
            if fresh == .authorized || fresh == .limited { onNext() }
        }
    }

    private func handleTap() {
        // Read FRESH — the cached @State can be stale by the time the user taps (caused the double-tap).
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        status = current
        switch current {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    status = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onNext() }
                    }
                }
            }
        case .denied, .restricted:
            // iOS never re-prompts once denied — Photos lives on the app's own Settings page, so this works.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            onNext()
        }
    }
}

// MARK: - iOS 26 Full-Screen Previews tip (only shown on iOS 26+)

private struct FullScreenPreviewTipStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 4,
            sectionLabel: "Optional",
            headline: "Turn off Full-Screen Previews.",
            bodyText: "On iOS 26, screenshots open a full editor instead of saving on their own — so Replr can't catch them hands-free.\n\nFor one-tap capture, open the Settings app → Screen Capture, and turn off Full-Screen Previews. (iOS doesn't let apps jump straight to that page.)\n\nThis is optional — capture still works without it; you'll just tap Save on each screenshot first.",
            onBack: onBack
        ) {
            EmptyView()
        } cta: {
            PrimaryButton(label: "Done →", action: onNext)
        }
    }
}

// MARK: - Root coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    @AppStorage("onboardingStep") private var step = 0

    /// Whether a permission step (1=keyboard, 2=full access, 3=photos) is already granted.
    private func isSatisfied(_ s: Int) -> Bool {
        switch s {
        case 1: return AppGroupService.shared.keyboardInstalled
        case 2: return AppGroupService.shared.fullAccessGranted
        case 3:
            let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return st == .authorized || st == .limited
        default: return false
        }
    }

    /// First permission step (1...3) at or after `from` that still needs action; 4 (tip/finish) if all met.
    private func nextStep(from: Int) -> Int {
        var s = max(from, 1)
        while s <= 3 {
            if !isSatisfied(s) { return s }
            s += 1
        }
        return 4
    }

    var body: some View {
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = nextStep(from: 1) }, onSignIn: onSignIn)
            case 1:
                AddKeyboardStep(onNext: { step = nextStep(from: 2) }, onBack: { step = 0 })
            case 2:
                FullAccessStep(onNext: { step = nextStep(from: 3) }, onBack: { step = 1 })
            case 3:
                PhotosPermissionStep(onNext: { step = 4 }, onBack: { step = 2 })
            case 4:
                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    FullScreenPreviewTipStep(onNext: { step = 0; onComplete() }, onBack: { step = 3 })
                } else {
                    // Older iOS auto-saves screenshots — no tip needed; finish onboarding.
                    Color.clear.onAppear { step = 0; onComplete() }
                }
            default:
                WelcomeStep(onNext: { step = nextStep(from: 1) }, onSignIn: onSignIn)
            }
        }
        .onAppear {
            if step > 4 { step = 0 }
            // If we resumed onto an already-granted permission step, skip forward to the first that needs action.
            if step >= 1 && step <= 3 && isSatisfied(step) {
                step = nextStep(from: step)
            }
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
                            .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
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
            .background(ReplrTheme.Color.bg.ignoresSafeArea())
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
