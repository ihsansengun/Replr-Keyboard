import SwiftUI
import Combine
import Photos
import Lottie

// MARK: - Lottie accent helper

private func replrAccentLottieColor(_ scheme: ColorScheme) -> LottieColor {
    let c = ReplrTheme.Color.accentRGBA(for: scheme)
    return LottieColor(r: c.r, g: c.g, b: c.b, a: c.a)
}

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
            .padding(.bottom, 16)

            Spacer(minLength: 24)

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

            Spacer(minLength: 24)

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

                    Text("Screenshot any chat. Replr reads it, drafts the reply, you tap to send.")
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

// Merged step — adding the keyboard and granting Full Access are the SAME gate
// (both flags are written together by the keyboard only once it runs with Full Access),
// so they're one screen. Avoids the confusing "do the keyboard thing twice" flow.
private struct KeyboardSetupStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var detected = AppGroupService.shared.fullAccessGranted
    @AppStorage("onboarding.keyboardSettingsOpened") private var settingsOpened = false

    var body: some View {
        OnboardingStep(
            step: 1, totalSteps: 3,
            sectionLabel: "Keyboard",
            headline: "Add Replr & allow Full Access.",
            bodyText: "Add the Replr keyboard, then turn on Full Access so it can draft replies. Already did it? Tap “I've enabled it” — we confirm the next time you open the Replr keyboard.",
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
                PrimaryButton(label: "All set ✓ — Continue →", action: onNext)
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
            step: 2, totalSteps: 3,
            sectionLabel: "Permissions",
            headline: "Allow Photos.",
            bodyText: "Replr drafts replies from the screenshot you take of a chat. Your photo library stays private:",
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 10) {
                privacyRow("Reads only your most-recent screenshot")
                privacyRow("Never scans or browses your other photos")
                privacyRow("Nothing else ever leaves your phone")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
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

    private func privacyRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 13))
                .foregroundColor(ReplrTheme.Color.success)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(ReplrTheme.Color.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - iOS 26 Full-Screen Previews tip (only shown on iOS 26+)

private struct FullScreenPreviewTipStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStep(
            step: 3, totalSteps: 3,
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

// MARK: - Ready (final handoff — how to start using the keyboard)

private struct ReadyStep: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ReplrMark(size: 14)
                    Spacer()
                    Text("All set")
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    OnboardingCelebration()
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)

                    Text("You're set up.")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(ReplrTheme.Color.textPrimary)

                    Text("Here's how it works — about 30 seconds.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(label: "Show me how →", action: onDone)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func howToRow(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundColor(ReplrTheme.Color.onAccent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(ReplrTheme.Color.accent))
            Text(text)
                .font(ReplrTheme.Font.callout)
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Root coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    var startAtSetup: Bool = false   // revisit from Settings: skip the Welcome screen
    @AppStorage("onboardingStep") private var step = 0

    /// Whether a permission step (1 = keyboard + Full Access, 2 = Photos) is already granted.
    private func isSatisfied(_ s: Int) -> Bool {
        switch s {
        case 1: return AppGroupService.shared.fullAccessGranted   // keyboard + Full Access are one signal
        case 2:
            let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return st == .authorized || st == .limited
        default: return false
        }
    }

    /// First permission step (1...2) at or after `from` that still needs action; 3 (tip/finish) if all met.
    private func nextStep(from: Int) -> Int {
        var s = max(from, 1)
        while s <= 2 {
            if !isSatisfied(s) { return s }
            s += 1
        }
        return 3
    }

    var body: some View {
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = nextStep(from: 1) }, onSignIn: onSignIn)
            case 1:
                KeyboardSetupStep(onNext: { step = nextStep(from: 2) }, onBack: { step = 0 })
            case 2:
                PhotosPermissionStep(onNext: { step = 3 }, onBack: { step = 1 })
            case 3:
                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    FullScreenPreviewTipStep(onNext: { step = 4 }, onBack: { step = 2 })
                } else {
                    // Older iOS auto-saves screenshots — no tip needed; go straight to the handoff.
                    Color.clear.onAppear { step = 4 }
                }
            case 4:
                ReadyStep(onDone: { step = 5 })
            case 5:
                UsageTutorialView(onDone: { step = 0; onComplete() })
            default:
                WelcomeStep(onNext: { step = nextStep(from: 1) }, onSignIn: onSignIn)
            }
        }
        .onAppear {
            if step > 5 { step = 0 }
            // Revisit from Settings: skip the Welcome marketing screen, go straight to setup.
            if startAtSetup && step == 0 {
                step = nextStep(from: 1)
            }
            // If we resumed onto an already-granted permission step, skip forward to the first that needs action.
            if step >= 1 && step <= 2 && isSatisfied(step) {
                step = nextStep(from: step)
            }
        }
    }
}

// MARK: - Usage tutorial (post-setup how-to; also revisitable from Settings)

/// A swipeable how-to carousel shown right after setup, and re-openable from
/// Settings. Steps: switch to Replr (long-press globe) -> pick Replr ->
/// minimise -> screenshot -> tap to send. Animation slots are placeholders
/// until the Lottie scenes are dropped in.
struct UsageTutorialView: View {
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private struct TutStep {
        let animation: LottieAnimation?
        let icon: String
        let title: String
        let body: String
    }

    private let steps: [TutStep] = [
        TutStep(animation: parseLottie(tutSwitchJSON), icon: "globe",
                title: "Switch to Replr",
                body: "In any chat, press and hold the 🌐 key on the keyboard to see your keyboards."),
        TutStep(animation: parseLottie(tutPickJSON), icon: "keyboard",
                title: "Pick Replr",
                body: "Tap Replr in the list to switch to it."),
        TutStep(animation: parseLottie(tutMinimiseJSON), icon: "arrow.down.right.and.arrow.up.left",
                title: "Minimise Replr",
                body: "Tap Start so the keyboard shrinks and you can see the whole chat."),
        TutStep(animation: parseLottie(tutScreenshotJSON), icon: "camera.viewfinder",
                title: "Screenshot the chat",
                body: "Take a screenshot — Replr reads it and drafts your replies."),
        TutStep(animation: parseLottie(tutSendJSON), icon: "sparkles",
                title: "Tap to send",
                body: "Your replies appear right in the keyboard. Tap one to drop it into the chat."),
    ]

    @State private var page = 0

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onDone)
                        .font(ReplrTheme.Font.caption)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { i in
                        stepPage(steps[i], number: i + 1).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? ReplrTheme.Color.accent : ReplrTheme.Color.textTertiary.opacity(0.35))
                            .frame(width: i == page ? 8 : 6, height: i == page ? 8 : 6)
                    }
                }
                .padding(.vertical, 18)

                PrimaryButton(label: page == steps.count - 1 ? "Start using Replr →" : "Next") {
                    if page == steps.count - 1 {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func stepPage(_ step: TutStep, number: Int) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            // Animation slot — Lottie demo of the step (icon fallback under Reduce Motion / parse failure).
            ZStack {
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .fill(ReplrTheme.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                            .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
                    )
                if let animation = step.animation, !reduceMotion {
                    LottieView(animation: animation)
                        .configure { $0.backgroundBehavior = .pauseAndRestore }
                        .valueProvider(
                            ColorValueProvider(replrAccentLottieColor(colorScheme)),
                            for: AnimationKeypath(keypath: "**.accent.Color"))
                        .looping()
                        .resizable()
                        .padding(14)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 54, weight: .light))
                        .foregroundColor(ReplrTheme.Color.accent)
                }
            }
            .frame(height: 210)
            .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Text("Step \(number) of \(steps.count)")
                    .font(ReplrTheme.Font.caption)
                    .foregroundColor(ReplrTheme.Color.accent)
                Text(step.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(step.body)
                    .font(ReplrTheme.Font.callout)
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 0)
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

// MARK: - Onboarding celebration (Lottie)

/// Plays the gamified setup checklist once and holds on the completed state
/// (all three tasks checked + the star burst). Under Reduce Motion (or if the
/// embedded JSON fails to parse) it shows the original static success checkmark.
/// Source asset: onboarding_steps.json (authored in LottieFiles Creator via the
/// Creator MCP; embedded below — app keyboard/onboarding files are explicitly
/// referenced, so a bundled resource isn't guaranteed to ship).
private struct OnboardingCelebration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Parsed once and cached.
    private static let animation: LottieAnimation? =
        try? LottieAnimation.from(data: Data(onboardingCelebrationLottieJSON.utf8))

    var body: some View {
        if reduceMotion || Self.animation == nil {
            ZStack {
                Circle()
                    .fill(ReplrTheme.Color.accent)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ReplrTheme.Color.onAccent)
            }
            .frame(maxWidth: .infinity)
        } else {
            LottieView(animation: Self.animation)
                .configure { $0.backgroundBehavior = .pauseAndRestore }
                .valueProvider(
                    ColorValueProvider(replrAccentLottieColor(colorScheme)),
                    for: AnimationKeypath(keypath: "**.accent.Color"))
                .playing(.toProgress(0.86, loopMode: .playOnce))
                .resizable()
        }
    }
}

private let onboardingCelebrationLottieJSON = ##"{"nm":"onboarding_steps","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"celebration","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"sr","bm":0,"hd":false,"nm":"Star Shape 1","d":1,"ir":{"a":0,"k":6},"is":{"a":0,"k":0},"pt":{"a":0,"k":5},"p":{"a":0,"k":[0,0]},"or":{"a":0,"k":13},"os":{"a":0,"k":0},"r":{"a":0,"k":0},"sy":1},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":56},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,120],"t":64},{"s":[100,100],"t":70}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,26]},"r":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[-25],"t":56},{"s":[0],"t":72}]},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":56},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":63},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]}],"ind":1},{"ty":4,"nm":"checkmarks","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"sh","bm":0,"hd":false,"nm":"Path Curve 1","d":1,"ks":{"a":0,"k":{"c":false,"i":[[0,0],[0,0],[0,0]],"o":[[0,0],[0,0],[0,0]],"v":[[-4.5,0.5],[-1.5,4],[5,-4.5]]}}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":13},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":22},{"s":[100,100],"t":27}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,56]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":13},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":19},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"sh","bm":0,"hd":false,"nm":"Path Curve 1","d":1,"ks":{"a":0,"k":{"c":false,"i":[[0,0],[0,0],[0,0]],"o":[[0,0],[0,0],[0,0]],"v":[[-4.5,0.5],[-1.5,4],[5,-4.5]]}}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":31},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":40},{"s":[100,100],"t":45}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,100]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":31},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":37},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"sh","bm":0,"hd":false,"nm":"Path Curve 1","d":1,"ks":{"a":0,"k":{"c":false,"i":[[0,0],[0,0],[0,0]],"o":[[0,0],[0,0],[0,0]],"v":[[-4.5,0.5],[-1.5,4],[5,-4.5]]}}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":49},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":58},{"s":[100,100],"t":63}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,144]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":49},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":55},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]}],"ind":2},{"ty":4,"nm":"checks","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[22,22]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":8},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":16},{"s":[100,100],"t":22}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,56]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":8},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":14},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[22,22]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":26},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":34},{"s":[100,100],"t":40}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,100]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":26},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":32},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[22,22]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0,0],"t":44},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[115,115],"t":52},{"s":[100,100],"t":58}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[40,144]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":44},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":50},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]}],"ind":3},{"ty":4,"nm":"progressFill","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[104,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":10},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":16},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[120,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":28},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":34},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[136,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":46},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":52},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":80},{"s":[0],"t":88}]}}]}],"ind":4},{"ty":4,"nm":"static","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[40,56]},"s":{"a":0,"k":[22,22]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[135,56]},"r":{"a":0,"k":5},"s":{"a":0,"k":[146,11]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":30}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[40,100]},"s":{"a":0,"k":[22,22]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[135,100]},"r":{"a":0,"k":5},"s":{"a":0,"k":[146,11]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":30}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[40,144]},"s":{"a":0,"k":[22,22]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[135,144]},"r":{"a":0,"k":5},"s":{"a":0,"k":[146,11]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":30}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[104,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":35}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[120,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":35}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[136,184]},"s":{"a":0,"k":[8,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":35}}]}],"ind":5}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##

// MARK: - Tutorial Lottie assets (authored in LottieFiles Creator via MCP)

private func parseLottie(_ json: String) -> LottieAnimation? {
    try? LottieAnimation.from(data: Data(json.utf8))
}

private let tutSwitchJSON = ##"{"nm":"tut_switch","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"popup","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[50,50],"t":18},{"s":[100,100],"t":32}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[110,92]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":18},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":30},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":74},{"s":[0],"t":84}]}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":10},"s":{"a":0,"k":[140,74]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":32}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":10},"s":{"a":0,"k":[140,74]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":1.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,-20]},"r":{"a":0,"k":4},"s":{"a":0,"k":[104,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":4},"s":{"a":0,"k":[104,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,20]},"r":{"a":0,"k":4},"s":{"a":0,"k":[104,8]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":55}}]}],"ind":1},{"ty":4,"nm":"press","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[40,40],"t":6},{"s":[170,170],"t":28}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[44,167]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[90],"t":6},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":28},{"s":[0],"t":90}]}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[28,28]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ind":2},{"ty":4,"nm":"globe","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[44,167]},"r":{"a":0,"k":6},"s":{"a":0,"k":[28,28]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[44,167]},"s":{"a":0,"k":[15,15]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":1.5},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[44,167]},"r":{"a":0,"k":0},"s":{"a":0,"k":[1.6,15]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[44,167]},"r":{"a":0,"k":0},"s":{"a":0,"k":[15,1.6]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ind":3},{"ty":4,"nm":"kbd","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":22}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,167]},"r":{"a":0,"k":8},"s":{"a":0,"k":[204,36]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}}],"ind":4}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
private let tutPickJSON = ##"{"nm":"tut_pick","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"tap","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[35,35],"t":18},{"s":[120,120],"t":36}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":18},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[90],"t":24},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":38},{"s":[0],"t":90}]}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[26,26]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ind":1},{"ty":4,"nm":"rows","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,72]},"r":{"a":0,"k":4},"s":{"a":0,"k":[108,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":50}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":4},"s":{"a":0,"k":[108,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":95}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,128]},"r":{"a":0,"k":4},"s":{"a":0,"k":[108,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":50}}]}],"ind":2},{"ty":4,"nm":"hl","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":26},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":40},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":74},{"s":[0],"t":84}]}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":7},"s":{"a":0,"k":[142,26]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}}],"ind":3},{"ty":4,"nm":"panel","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":12},"s":{"a":0,"k":[162,112]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":28}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":12},"s":{"a":0,"k":[162,112]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":1.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":60}}]}],"ind":4}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
private let tutMinimiseJSON = ##"{"nm":"tut_minimise","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"keyboard","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,154],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,154],"t":15},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,171],"t":35},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[120,171],"t":75},{"s":[120,154],"t":90}]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":7},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,44],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,44],"t":15},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,10],"t":35},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[104,10],"t":75},{"s":[104,44],"t":90}]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}}],"ind":1},{"ty":4,"nm":"bubbles","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4},"s":{"a":0,"k":[50,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4},"s":{"a":0,"k":[36,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":44}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4},"s":{"a":0,"k":[54,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]}],"ind":2},{"ty":4,"nm":"phone","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":60}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18},"s":{"a":0,"k":[120,170]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}}],"ind":3}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
private let tutScreenshotJSON = ##"{"nm":"tut_screenshot","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"flash","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":30},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[82],"t":38},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":48},{"s":[0],"t":90}]}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":14},"s":{"a":0,"k":[116,166]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}}],"ind":1},{"ty":4,"nm":"keyboard","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,171]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":5},"s":{"a":0,"k":[104,10]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}}],"ind":2},{"ty":4,"nm":"bubbles","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4},"s":{"a":0,"k":[50,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4},"s":{"a":0,"k":[36,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":44}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4},"s":{"a":0,"k":[54,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]}],"ind":3},{"ty":4,"nm":"phone","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":60}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18},"s":{"a":0,"k":[120,170]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}}],"ind":4}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
private let tutSendJSON = ##"{"nm":"tut_send","ddd":0,"h":200,"w":240,"meta":{"g":"@lottiefiles/creator@1.94.0"},"layers":[{"ty":4,"nm":"tap","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[35,35],"t":40},{"s":[120,120],"t":58}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,171]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":40},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[90],"t":46},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":60},{"s":[0],"t":90}]}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"el","bm":0,"hd":false,"nm":"Ellipse Shape 1","d":1,"p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[26,26]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2},"c":{"a":0,"k":[1,1,1]}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}}]}],"ind":1},{"ty":4,"nm":"chips","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[55,55],"t":10},{"s":[100,100],"t":24}]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,171]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":1,"k":[{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":0},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[0],"t":10},{"o":{"x":0.34,"y":0},"i":{"x":0.66,"y":1},"s":[100],"t":22},{"s":[100],"t":90}]}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[-22,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 2","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 3","d":1,"p":{"a":0,"k":[22,0]},"r":{"a":0,"k":3},"s":{"a":0,"k":[16,6]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[1,1,1]},"r":1,"o":{"a":0,"k":100}}],"ind":2},{"ty":4,"nm":"keyboard","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[120,171]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":5},"s":{"a":0,"k":[104,10]}},{"ty":"fl","bm":0,"hd":false,"nm":"accent","c":{"a":0,"k":[1.0,0.435,0.569]},"r":1,"o":{"a":0,"k":100}}],"ind":3},{"ty":4,"nm":"bubbles","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":100}},"shapes":[{"ty":"gr","bm":0,"hd":false,"nm":"Group","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[92,44]},"r":{"a":0,"k":4},"s":{"a":0,"k":[50,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[150,62]},"r":{"a":0,"k":4},"s":{"a":0,"k":[36,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":44}}]},{"ty":"gr","bm":0,"hd":false,"nm":"Group 1","it":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[96,80]},"r":{"a":0,"k":4},"s":{"a":0,"k":[54,9]}},{"ty":"fl","bm":0,"hd":false,"nm":"Fill","c":{"a":0,"k":[0.502,0.549,0.6196]},"r":1,"o":{"a":0,"k":100}},{"ty":"tr","a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":26}}]}],"ind":4},{"ty":4,"nm":"phone","sr":1,"st":0,"op":90,"ip":0,"hd":false,"ddd":0,"bm":0,"hasMask":false,"ao":0,"ks":{"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"sk":{"a":0,"k":0},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"sa":{"a":0,"k":0},"o":{"a":0,"k":60}},"shapes":[{"ty":"rc","bm":0,"hd":false,"nm":"Rect Shape 1","d":1,"p":{"a":0,"k":[120,100]},"r":{"a":0,"k":18},"s":{"a":0,"k":[120,170]}},{"ty":"st","bm":0,"hd":false,"nm":"Stroke","lc":2,"lj":2,"ml":1,"o":{"a":0,"k":100},"w":{"a":0,"k":2.5},"c":{"a":0,"k":[0.502,0.549,0.6196]}}],"ind":5}],"v":"5.7.0","fr":30,"op":90,"ip":0,"assets":[]}"##
