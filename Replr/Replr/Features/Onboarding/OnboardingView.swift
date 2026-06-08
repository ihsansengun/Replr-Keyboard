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
                    .font(ReplrTheme.Font.serif(28, weight: .bold))
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

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    ReplrMark(size: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("The reply is")
                            .font(ReplrTheme.Font.serif(34, weight: .bold))
                            .foregroundStyle(ReplrTheme.Color.textPrimary)
                        Text("already written.")
                            .font(ReplrTheme.Font.serif(34, weight: .bold))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                    }

                    Text("Screenshot any chat. Replr reads it, drafts the reply, you tap to send.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                        .lineSpacing(4)

                    Text("Free to try. No credit card.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.accent)

                    Text("Your conversations are sent to generate replies, then discarded. Nothing stored on any server. See Privacy in Settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(ReplrTheme.Color.textTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                Spacer()

                PrimaryButton(label: "Set it up →", action: onNext)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }
}

// Merged step — adding the keyboard and granting Full Access are the SAME gate
// (both flags are written together by the keyboard only once it runs with Full Access),
// so they're one screen. Avoids the confusing "do the keyboard thing twice" flow.
// MARK: - Branded iOS-settings previews (onboarding setup steps)

/// A non-interactive iOS-style toggle in its ON (green) state — shows the goal state.
private struct SettingsOnToggle: View {
    var body: some View {
        Capsule()
            .fill(ReplrTheme.Color.success)
            .frame(width: 42, height: 25)
            .overlay(alignment: .trailing) {
                Circle().fill(.white).frame(width: 21, height: 21).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
    }
}

/// Small grey rounded-square glyph, like an iOS Settings row icon.
private func settingsRowIcon(_ systemName: String) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white)
        .frame(width: 26, height: 26)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ReplrTheme.Color.textSecondary))
}

private func settingsCardChrome<V: View>(_ content: V) -> some View {
    content
        .background(ReplrTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
}

/// Replica of Settings → General → Keyboards, in Replr branding: the ReplrKeyboard +
/// Allow Full Access toggles, shown ON so the user sees the goal.
private struct KeyboardSettingsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings › General › Keyboards")
                .font(.system(size: 11))
                .foregroundColor(ReplrTheme.Color.textTertiary)
                .padding(.leading, 4)
            settingsCardChrome(
                VStack(spacing: 0) {
                    HStack(spacing: 11) {
                        Text("ReplrKeyboard")
                            .font(.system(size: 14))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Spacer()
                        SettingsOnToggle()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    Divider().overlay(ReplrTheme.Color.glassBorder).padding(.leading, 14)

                    HStack(spacing: 11) {
                        settingsRowIcon("keyboard")
                        Text("Allow Full Access")
                            .font(.system(size: 14))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Spacer()
                        SettingsOnToggle()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
            )
        }
    }
}

/// Approximation of the multicolour Apple Photos app icon — a rainbow pinwheel on white.
/// Deliberately uses literal system-icon colours (not Replr tokens): it's a faithful
/// replica of Apple's icon so the preview is recognisable, not a Replr-branded element.
private struct PhotosAppIcon: View {
    private static let petals: [Color] = [
        Color(red: 0.99, green: 0.79, blue: 0.21),  // yellow (top)
        Color(red: 0.45, green: 0.78, blue: 0.36),  // green
        Color(red: 0.18, green: 0.74, blue: 0.73),  // teal
        Color(red: 0.25, green: 0.52, blue: 0.92),  // blue
        Color(red: 0.50, green: 0.34, blue: 0.80),  // purple
        Color(red: 0.86, green: 0.27, blue: 0.62),  // magenta
        Color(red: 0.94, green: 0.27, blue: 0.30),  // red
        Color(red: 0.97, green: 0.55, blue: 0.16),  // orange
    ]
    var body: some View {
        ZStack {
            ForEach(Self.petals.indices, id: \.self) { i in
                Capsule()
                    .fill(Self.petals[i])
                    .frame(width: 5.5, height: 13)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle().fill(.white).frame(width: 7, height: 7)   // bright centre
        }
        .frame(width: 26, height: 26)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(ReplrTheme.Color.glassBorder, lineWidth: 0.5))
    }
}

/// Replica of Settings → Replr → "Allow Replr to Access" → Photos: Full Access.
private struct PhotosSettingsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow Replr to Access")
                .font(.system(size: 11))
                .foregroundColor(ReplrTheme.Color.textTertiary)
                .padding(.leading, 4)
            settingsCardChrome(
                HStack(spacing: 11) {
                    PhotosAppIcon()
                    Text("Photos")
                        .font(.system(size: 14))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Full Access")
                            .font(.system(size: 13))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            )
        }
    }
}

private struct KeyboardSetupStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var detected = AppGroupService.shared.fullAccessGranted
    @AppStorage("onboarding.keyboardSettingsOpened") private var settingsOpened = false

    var body: some View {
        OnboardingStep(
            step: 2, totalSteps: 4,
            sectionLabel: "Keyboard",
            headline: "Add Replr & allow Full Access.",
            bodyText: "Add the Replr keyboard, then turn on Full Access so it can draft your replies.",
            onBack: onBack
        ) {
            VStack(spacing: 14) {
                PrimingCard(
                    icon: "lock.shield",
                    lead: "Your data is ",
                    highlight: "safe",
                    trail: ".",
                    detail: "Full Access lets Replr work across your apps. Nothing you type is stored."
                )
                KeyboardSettingsPreview()
            }
        } cta: {
            if detected {
                PrimaryButton(label: "All set. Continue →", action: onNext)
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
            bodyText: "Replr drafts replies from the screenshot you take of a chat. Your photo library stays private:",
            onBack: onBack
        ) {
            VStack(spacing: 14) {
                PhotosSettingsPreview()

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
            }
        } cta: {
            if granted {
                PrimaryButton(label: "Photos allowed. Continue →", action: onNext)
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

// (Removed: the iOS 26 Full-Screen Previews tip now lives in Settings → Screenshots.)

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

                VStack(spacing: 16) {
                    OnboardingCelebration()
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)

                    Text("You're set up.")
                        .font(ReplrTheme.Font.serif(32, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("One quick demo, then you're ready.")
                        .font(ReplrTheme.Font.callout)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(label: "See it in action →", action: onDone)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    
}

// MARK: - Priming card (reused on permission steps)

/// A calm reassurance card: a serif line with one accent-highlighted word + a detail line.
private struct PrimingCard: View {
    let icon: String
    let lead: String
    let highlight: String
    let trail: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.accent)
            (Text(lead)
             + Text(highlight).foregroundColor(ReplrTheme.Color.accent)
             + Text(trail))
                .font(ReplrTheme.Font.serif(19, weight: .semibold))
                .foregroundColor(ReplrTheme.Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(ReplrTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Root coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    var onSignIn: () -> Void = {}
    var startAtSetup: Bool = false   // revisit from Settings: skip the Welcome screen
    @AppStorage("onboardingStep") private var step = 0

    /// Whether a permission step (3 = keyboard + Full Access, 4 = Photos) is already granted.
    private func isSatisfied(_ s: Int) -> Bool {
        switch s {
        case 3: return AppGroupService.shared.fullAccessGranted   // keyboard + Full Access are one signal
        case 4:
            let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return st == .authorized || st == .limited
        default: return false
        }
    }

    /// First permission step (3...4) at or after `from` that still needs action; 5 (Back Tap) if all met.
    private func nextPermission(from: Int) -> Int {
        var s = max(from, 3)
        while s <= 4 {
            if !isSatisfied(s) { return s }
            s += 1
        }
        return 5
    }

    var body: some View {
        Group {
            switch step {
            case 0:
                WelcomeStep(onNext: { step = 1 })
            case 1:
                IntroCarouselStep(onDone: { step = 2 })
            case 2:
                PersonalizationSurveyStep(step: 1, totalSteps: 4,
                                          onNext: { step = nextPermission(from: 3) },
                                          onBack: { step = 1 })
            case 3:
                KeyboardSetupStep(onNext: { step = nextPermission(from: 4) }, onBack: { step = 2 })
            case 4:
                PhotosPermissionStep(onNext: { step = 5 }, onBack: { step = 3 })
            case 5:
                BackTapOnboardingStep(step: 4, totalSteps: 4,
                                      onNext: { step = 6 }, onBack: { step = 4 })
            case 6:
                ReadyStep(onDone: { step = 7 })
            case 7:
                SampleDemoStep(onFinish: { step = 0; onComplete() })
            default:
                WelcomeStep(onNext: { step = 1 })
            }
        }
        .onAppear {
            if step > 7 { step = 0 }
            // Revisit from Settings: skip the intro + survey, jump to the first unmet permission.
            if startAtSetup && step == 0 {
                step = nextPermission(from: 3)
            }
            // If we resumed onto an already-granted permission step, skip forward.
            if (step == 3 || step == 4) && isSatisfied(step) {
                step = nextPermission(from: step)
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
        var heroFlow: Bool = false
    }

    /// Approved placeholder hero for the "Steer the reply" step: a 3-tile flow
    /// (you type → switch to Replr → on-target replies). Pure SwiftUI, theme-
    /// tokened; a polished Lottie replaces it in the tutorial-animation redo.
    private struct SteerFlowStrip: View {
        var body: some View {
            HStack(spacing: 7) {
                tile(icon: "square.and.pencil", caption: "you type", sub: "\u{201C}ask her out\u{201D}", highlight: false)
                arrow
                tile(icon: "globe", caption: "switch to\nReplr", sub: nil, highlight: true)
                arrow
                tile(icon: "bubble.left.and.bubble.right.fill", caption: "on-target\nreplies", sub: nil, highlight: false)
            }
            .padding(.horizontal, 14)
        }

        private var arrow: some View {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ReplrTheme.Color.accent)
        }

        private func tile(icon: String, caption: String, sub: String?, highlight: Bool) -> some View {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(highlight ? ReplrTheme.Color.onAccent : ReplrTheme.Color.accent)
                Text(caption)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(highlight ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                if let sub {
                    Text(sub)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.accent)
                        .lineLimit(1)
                }
            }
            .frame(width: 66, height: 78)
            .background(
                Group {
                    if highlight {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(ReplrTheme.Color.brandGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(ReplrTheme.Color.surfaceRaised)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(highlight ? Color.clear : ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }

    private let steps: [TutStep] = [
        TutStep(animation: parseLottie(tutSwitchJSON), icon: "globe",
                title: "Switch to Replr",
                body: "Replr writes your replies. It isn't for typing. Keep using your normal keyboard; press and hold 🌐 to bring up Replr whenever you want a reply."),
        TutStep(animation: parseLottie(tutPickJSON), icon: "keyboard",
                title: "Pick Replr",
                body: "Tap Replr in the list to switch to it."),
        TutStep(animation: parseLottie(tutMinimiseJSON), icon: "arrow.down.right.and.arrow.up.left",
                title: "Minimise Replr",
                body: "Tap Start so the keyboard shrinks and you can see the whole chat."),
        TutStep(animation: parseLottie(tutScreenshotJSON), icon: "camera.viewfinder",
                title: "Screenshot the chat",
                body: "Take a screenshot. Replr reads it and drafts your replies."),
        TutStep(animation: parseLottie(tutSendJSON), icon: "sparkles",
                title: "Tap to send",
                body: "Your replies appear right in the keyboard. Tap one to drop it into the chat."),
        TutStep(animation: nil, icon: "text.cursor",
                title: "Steer the reply",
                body: "Optional: type what you want to say first, like \"ask her to dinner\", then switch to Replr and tap Start. Your replies come back built around it.",
                heroFlow: true),
        TutStep(animation: nil, icon: "hand.tap",
                title: "Reply anywhere with Back Tap",
                body: "Optional: set up a triple-tap on the back of your phone to capture any screen, even dating profiles, where the keyboard can't open. Turn it on in Settings → Keyboard → Back Tap capture."),
    ]

    @State private var page: Int

    /// `startTopic` (from a deep link like replr://tutorial/steer) opens the tutorial directly at
    /// that step instead of from the beginning. Indices map to `steps` below — keep in sync.
    init(startTopic: String? = nil, onDone: @escaping () -> Void) {
        self.onDone = onDone
        let idx: Int
        switch startTopic {
        case "steer":   idx = 5   // "Steer the reply"
        case "backtap": idx = 6   // "Reply anywhere with Back Tap"
        default:        idx = 0
        }
        _page = State(initialValue: idx)
    }

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

                PrimaryButton(label: page == steps.count - 1 ? "Start using Replr →" : "Next") {
                    if page == steps.count - 1 {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .padding(.top, 16)
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
                if step.heroFlow {
                    SteerFlowStrip()
                } else if let animation = step.animation, !reduceMotion {
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
                        Text("Triple-tap = instant openers.")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("Works anywhere, even on dating profiles, where the keyboard can't open. Triple-tap the back of your phone: Replr screenshots what's on screen and drafts replies. Nothing is saved to your Photos. Two-minute, one-time setup.")
                            .font(ReplrTheme.Font.callout)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .lineSpacing(3)
                    }

                    // Step 1 — add the shortcut (one tap → opens the iCloud shortcut)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("1")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundColor(ReplrTheme.Color.onAccent)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(ReplrTheme.Color.accent))
                            Text("Add the Replr Capture shortcut")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                        }
                        Text("Opens the Shortcuts app. Tap \"Add Shortcut\" to confirm.")
                            .font(ReplrTheme.Font.footnote)
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .lineSpacing(2)
                        PrimaryButton(label: "Add shortcut →") {
                            if let url = URL(string: AppGroupService.shared.effectiveShortcutInstallURL) {
                                UIApplication.shared.open(url)
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

                    // Step 2 — assign it to Back Tap (manual — iOS has no deep link to Back Tap)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("2")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundColor(ReplrTheme.Color.onAccent)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(ReplrTheme.Color.accent))
                            Text("Assign it to Back Tap")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                        }
                        ForEach(Array([
                            "Open Settings → Accessibility → Touch → Back Tap",
                            "Tap \"Triple Tap\" (or \"Double Tap\")",
                            "Scroll to Shortcuts and choose \"Replr Capture\""
                        ].enumerated()), id: \.offset) { idx, text in
                            HStack(alignment: .top, spacing: 10) {
                                Text("•")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(ReplrTheme.Color.accent)
                                Text(text)
                                    .font(ReplrTheme.Font.callout)
                                    .foregroundColor(ReplrTheme.Color.textPrimary)
                                    .lineSpacing(2)
                            }
                        }
                        TertiaryButton(label: "Open Settings app →") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
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

                    Text("First triple-tap, iOS asks to allow Replr to receive the screenshot. Tap \"Allow Always.\"")
                        .font(ReplrTheme.Font.footnote)
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .lineSpacing(3)

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
