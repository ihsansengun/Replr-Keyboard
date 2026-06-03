import SwiftUI
import Combine
import UserNotifications

// MARK: - iOS Settings mockup palette (hardcoded to match real iOS dark UI)

private enum IOSMock {
    static let bg             = Color.black
    static let cardBg         = Color(white: 0.11)   // #1c1c1e
    static let divider        = Color(white: 0.14)
    static let labelPrimary   = Color.white
    static let labelSecondary = Color(white: 0.56)   // #8e8e93
    static let backCircle     = Color(white: 0.17)   // #2c2c2e
    static let toggleOn       = Color(red: 0.20, green: 0.78, blue: 0.35) // iOS green
}

// MARK: - Shared sub-components

private struct IOSNavBar: View {
    let title: String
    var showBack: Bool = true

    var body: some View {
        ZStack {
            if showBack {
                HStack {
                    ZStack {
                        Circle()
                            .fill(IOSMock.backCircle)
                            .frame(width: 32, height: 32)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(height: 44)
        .background(IOSMock.bg)
    }
}

private struct IOSRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(IOSMock.divider)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

private struct TapHereChip: View {
    var body: some View {
        Text("TAP HERE")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(ReplrTheme.Color.onAccent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(ReplrTheme.Color.accent)
            .clipShape(Capsule())
    }
}

private struct IOSRow: View {
    let label: String
    var value: String? = nil
    var icon: String? = nil
    var iconColor: Color = .blue
    var isHighlighted: Bool = false
    var showChevron: Bool = true
    var opacity: Double = 1.0

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(isHighlighted ? ReplrTheme.Color.accent : IOSMock.labelPrimary)
            Spacer()
            if isHighlighted { TapHereChip() }
            if let value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(IOSMock.labelSecondary)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isHighlighted ? ReplrTheme.Color.accent : IOSMock.labelSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(isHighlighted ? ReplrTheme.Color.accent.opacity(0.09) : IOSMock.cardBg)
        .opacity(opacity)
    }
}

private struct IOSToggleRow: View {
    let label: String
    var isOn: Bool = true
    var description: String? = nil
    var opacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 17))
                    .foregroundColor(IOSMock.labelPrimary)
                Spacer()
                Capsule()
                    .fill(isOn ? IOSMock.toggleOn : Color(white: 0.23))
                    .frame(width: 48, height: 28)
                    .overlay(
                        Circle().fill(.white).frame(width: 24, height: 24)
                            .offset(x: isOn ? 10 : -10), alignment: .center
                    )
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            if let description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(IOSMock.labelSecondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
        .background(IOSMock.cardBg)
        .opacity(opacity)
    }
}

// A card that wraps a single row (Touch screen style)
private struct IOSSoloCard<Content: View>: View {
    var isHighlighted: Bool = false
    var opacity: Double = 1.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isHighlighted ? ReplrTheme.Color.accent.opacity(0.45) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal, 16)
            .opacity(opacity)
    }
}

// A card that wraps multiple rows with internal dividers
private struct IOSGroupCard<Content: View>: View {
    var opacity: Double = 1.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .opacity(opacity)
    }
}

// Mini progress dots for sub-steps (e.g. ● ○ ○ ○ ○)
private struct SubStepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? ReplrTheme.Color.accent : ReplrTheme.Color.border)
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
    }
}

// MARK: - Sub-step 1: Settings root → Accessibility

// IMPORTANT: These sub-step views do NOT contain instruction text (headline/body) — that's
// handled by OnboardingStep above them. They only show SubStepDots + the iOS mockup.
// OnboardingStep applies .padding(.horizontal, 24) to content(), so sub-step views
// must NOT add their own outer horizontal padding.

struct BackTapSubStep1: View {
    var body: some View {
        VStack(spacing: 12) {
            SubStepDots(current: 1, total: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(IOSMock.bg)

                IOSGroupCard {
                    IOSRow(label: "General",
                           icon: "gearshape.fill", iconColor: Color(white: 0.39),
                           opacity: 0.35)
                    IOSRowDivider()
                    IOSRow(label: "Accessibility",
                           icon: "figure.arms.open", iconColor: Color(red: 0.04, green: 0.52, blue: 1.0),
                           isHighlighted: true)
                    IOSRowDivider()
                    IOSRow(label: "Action Button",
                           icon: "button.programmable", iconColor: Color(white: 0.39),
                           opacity: 0.35)
                }
                .padding(.vertical, 8)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Sub-step 2: Accessibility → Touch

struct BackTapSubStep2: View {
    var body: some View {
        VStack(spacing: 12) {
            SubStepDots(current: 2, total: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                IOSNavBar(title: "Accessibility")

                Text("Physical and Motor")
                    .font(.system(size: 13))
                    .foregroundColor(IOSMock.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(IOSMock.bg)

                IOSGroupCard {
                    IOSRow(label: "Touch",
                           icon: "hand.point.up.left.fill",
                           iconColor: Color(red: 0.04, green: 0.52, blue: 1.0),
                           isHighlighted: true)
                    IOSRowDivider()
                    IOSRow(label: "Face ID & Attention",
                           icon: "faceid", iconColor: Color(red: 0.2, green: 0.78, blue: 0.35),
                           opacity: 0.35)
                    IOSRowDivider()
                    IOSRow(label: "Switch Control",
                           value: "Off",
                           icon: "rectangle.grid.2x2.fill", iconColor: Color(white: 0.39),
                           opacity: 0.35)
                }
                .padding(.vertical, 8)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Sub-step 3: Touch → Back Tap

struct BackTapSubStep3: View {
    var body: some View {
        VStack(spacing: 12) {
            SubStepDots(current: 3, total: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                IOSNavBar(title: "Touch")

                VStack(spacing: 10) {
                    IOSSoloCard(opacity: 0.35) {
                        IOSToggleRow(label: "Shake to Undo", isOn: true,
                                     description: "If you tend to shake your iPhone by accident…")
                    }
                    IOSSoloCard(opacity: 0.35) {
                        IOSToggleRow(label: "Vibration", isOn: true)
                    }
                    IOSSoloCard(isHighlighted: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            IOSRow(label: "Back Tap", value: "On", isHighlighted: true)
                            Text("Double- or triple-tap the back of your iPhone to perform actions quickly.")
                                .font(.system(size: 13))
                                .foregroundColor(ReplrTheme.Color.accent.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.bottom, 10)
                        }
                    }
                    IOSSoloCard(opacity: 0.35) {
                        IOSToggleRow(label: "Prefer Single-Touch Actions", isOn: false)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Sub-step 4: Back Tap → Double Tap

struct BackTapSubStep4: View {
    var body: some View {
        VStack(spacing: 12) {
            SubStepDots(current: 4, total: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                IOSNavBar(title: "Back Tap")

                VStack(spacing: 10) {
                    IOSGroupCard {
                        IOSRow(label: "Double Tap", value: "None", isHighlighted: true)
                        IOSRowDivider()
                        IOSRow(label: "Triple Tap", value: "None", opacity: 0.45)
                    }
                    IOSGroupCard(opacity: 0.35) {
                        IOSToggleRow(label: "Show Banner", isOn: true)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Sub-step 5: Double Tap list → Replr Capture

struct BackTapSubStep5: View {
    var body: some View {
        VStack(spacing: 12) {
            SubStepDots(current: 5, total: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                IOSNavBar(title: "Double Tap")

                VStack(spacing: 0) {
                    Text("Shortcuts")
                        .font(.system(size: 13))
                        .foregroundColor(IOSMock.labelSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(IOSMock.bg)

                    VStack(spacing: 0) {
                        flatRow("Quick Dictation to Clipboard", opacity: 0.3)
                        flatDivider()
                        flatRow("Quick Reply", opacity: 0.3)
                        flatDivider()
                        flatRow("Read Later", opacity: 0.3)
                        flatDivider()
                        HStack {
                            Text("Replr Capture")
                                .font(.system(size: 17))
                                .foregroundColor(ReplrTheme.Color.accent)
                            TapHereChip()
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.accent)
                        }
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(ReplrTheme.Color.accent.opacity(0.09))
                        flatDivider()
                        flatRow("…", opacity: 0.15)
                    }
                }
                .background(IOSMock.bg)

                Text("↑ scroll up to find it")
                    .font(.system(size: 11))
                    .foregroundColor(IOSMock.labelSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(IOSMock.bg)
            }
            .background(ReplrTheme.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                    .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
            )
        }
    }

    private func flatRow(_ label: String, opacity: Double = 1.0) -> some View {
        Text(label)
            .font(.system(size: 17))
            .foregroundColor(IOSMock.labelPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(IOSMock.bg)
            .opacity(opacity)
    }

    private func flatDivider() -> some View {
        Rectangle()
            .fill(IOSMock.divider)
            .frame(height: 0.5)
            .padding(.leading, 20)
    }
}

// MARK: - Notification helpers

private func scheduleBackTapReminder() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Back Tap reminder"
        content.body = "Accessibility → Touch → Back Tap → Double Tap (or Triple Tap) → Replr Capture"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
        let request = UNNotificationRequest(
            identifier: "replr.backtap.reminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

private func cancelBackTapReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: ["replr.backtap.reminder"]
    )
}

// MARK: - Confirm screen
// Only the visual element — OnboardingStep renders the badge/headline/body above this.

private struct BackTapConfirmScreen: View {
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(ReplrTheme.Color.accent.opacity(pulsing ? 0 : 0.25), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulsing ? 1.2 : 1.0)
                Circle()
                    .stroke(ReplrTheme.Color.accent.opacity(0.1), lineWidth: 16)
                    .frame(width: 80, height: 80)
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 28))
                    .foregroundColor(ReplrTheme.Color.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }

            Text("Tap-tap on the back of your phone. The app will react when it detects the gesture.")
                .font(ReplrTheme.Font.callout)
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(20)
        .background(ReplrTheme.Color.accent.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
    }
}

// MARK: - Success screen
// Only the visual element — OnboardingStep renders the badge/headline/body above this.

private struct BackTapSuccessScreen: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ReplrTheme.Color.accent)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ReplrTheme.Color.onAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            Text("Gesture confirmed! Replr is wired to your back tap — one gesture, from anywhere, forever.")
                .font(ReplrTheme.Font.callout)
                .foregroundColor(ReplrTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(20)
        .background(ReplrTheme.Color.accent.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.accent.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
    }
}

// MARK: - BackTapStep (public — used by OnboardingView.swift)

struct BackTapStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    enum SetupState: Equatable {
        case preview(substep: Int)
        case confirm
        case success
    }

    @State private var state: SetupState = .preview(substep: 1)
    @State private var confirmEnteredAt: Date?
    @State private var goingForward = true

    // MARK: - Carousel helpers (internal for testability)

    /// Advances to the next sub-step, wrapping 5 → 1.
    static func nextSubstep(from current: Int) -> Int {
        current < 5 ? current + 1 : 1
    }

    /// Steps back to the previous sub-step, wrapping 1 → 5.
    static func prevSubstep(from current: Int) -> Int {
        current > 1 ? current - 1 : 5
    }

    /// Timestamp of the last carousel navigation — used to pace auto-advance.
    @State private var lastNavTime: Date = Date()

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OnboardingStep(
            step: 4, totalSteps: 4,
            sectionLabel: sectionLabel,
            headline: headline,
            bodyText: bodyText,
            onBack: backAction
        ) {
            contentView
                .padding(.bottom, 8)
        } cta: {
            ctaView
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onAppear {
            lastNavTime = Date()
            if AppGroupService.shared.backTapSetupStarted {
                state = .confirm
                confirmEnteredAt = Date()
            }
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            pollForIntentFire()
            autoAdvanceCarousel()
        }
    }

    // MARK: - Dynamic text (drives OnboardingStep header)

    private var sectionLabel: String {
        switch state {
        case .preview: return "Back Tap"
        case .confirm: return "Confirm"
        case .success: return "You're ready"
        }
    }

    private var headline: String {
        switch state {
        case .preview(let substep):
            switch substep {
            case 1: return "Open Settings, find Accessibility."
            case 2: return "Tap Touch."
            case 3: return "Scroll down, tap Back Tap."
            case 4: return "Tap Double Tap."
            default: return "Scroll down, tap Replr Capture."
            }
        case .confirm: return "Test the gesture."
        case .success: return "Back Tap is live."
        }
    }

    private var bodyText: String {
        switch state {
        case .preview(let substep):
            switch substep {
            case 1: return "Tap the back button if you see Replr's settings, then scroll to Accessibility."
            case 2: return "Under \"Physical and Motor\" — it's near the top of Accessibility."
            case 3: return "It's its own card, about halfway down the Touch screen."
            case 4: return "One less tap. Use Triple Tap instead if it misfires accidentally."
            default: return "Under Shortcuts — scroll down until you see Replr Capture. Then come back here."
            }
        case .confirm:
            return "Tap the back of your phone now — double or triple, whichever you chose — to confirm it's wired up."
        case .success:
            return "Tap from any chat. Replies appear in your keyboard instantly."
        }
    }

    // MARK: - Back navigation

    private var backAction: (() -> Void)? {
        switch state {
        case .preview(let substep):
            if substep == 1 { return onBack }
            return {
                goingForward = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    state = .preview(substep: substep - 1)
                }
            }
        case .confirm:
            return { state = .preview(substep: 5) }
        case .success:
            return nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .preview(let substep):
            Group {
                switch substep {
                case 1: BackTapSubStep1()
                case 2: BackTapSubStep2()
                case 3: BackTapSubStep3()
                case 4: BackTapSubStep4()
                default: BackTapSubStep5()
                }
            }
            .id("preview-\(substep)")
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let isLeftSwipe = value.translation.width < -60
                        let isRightSwipe = value.translation.width > 60
                        if isLeftSwipe, substep < 5 {
                            goingForward = true
                            withAnimation(.easeInOut(duration: 0.25)) {
                                state = .preview(substep: substep + 1)
                            }
                        } else if isRightSwipe, substep > 1 {
                            goingForward = false
                            withAnimation(.easeInOut(duration: 0.25)) {
                                state = .preview(substep: substep - 1)
                            }
                        }
                    }
            )
        case .confirm:
            BackTapConfirmScreen()
                .transition(.opacity)
        case .success:
            BackTapSuccessScreen()
                .transition(.opacity)
        }
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaView: some View {
        switch state {
        case .preview(let substep):
            if substep < 5 {
                PrimaryButton(label: "Next →") {
                    goingForward = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        state = .preview(substep: substep + 1)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    PrimaryButton(label: "Open Settings →") {
                        openSettings()
                    }
                    TertiaryButton(label: "Already set up →") {
                        state = .confirm
                        confirmEnteredAt = Date()
                    }
                }
            }

        case .confirm:
            TertiaryButton(label: "Skip for now →") {
                cancelBackTapReminder()
                AppGroupService.shared.backTapSetupStarted = false
                onNext()
            }

        case .success:
            PrimaryButton(label: "Start using Replr →") {
                onNext()
            }
        }
    }

    // MARK: - Actions

    private func openSettings() {
        AppGroupService.shared.backTapSetupStarted = true
        scheduleBackTapReminder()
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active,
              AppGroupService.shared.backTapSetupStarted,
              state != .success else { return }
        withAnimation {
            state = .confirm
            confirmEnteredAt = Date()
        }
    }

    private func autoAdvanceCarousel() {
        guard case .preview(let substep) = state,
              Date().timeIntervalSince(lastNavTime) >= 2.2 else { return }
        lastNavTime = Date()
        goingForward = true
        withAnimation(.easeInOut(duration: 0.25)) {
            state = .preview(substep: BackTapStep.nextSubstep(from: substep))
        }
    }

    private func pollForIntentFire() {
        guard state == .confirm,
              let entered = confirmEnteredAt,
              let fired = AppGroupService.shared.lastIntentFiredAt,
              fired > entered else { return }
        withAnimation {
            state = .success
        }
        cancelBackTapReminder()
        AppGroupService.shared.backTapSetupStarted = false
    }
}
