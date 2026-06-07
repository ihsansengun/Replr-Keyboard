import SwiftUI
import Combine
import UIKit
import Photos  // SPIKE — remove after Phase 0

// MARK: - State

enum KeyboardState: Equatable {
    case idle
    case loading
    case replies([String])
    case error(String)
    case disambiguate(name: String, candidates: [Contact])
    case paywall
}

enum KeyboardInputMode: Equatable, Hashable { case chat, email }

// MARK: - Model

@MainActor
final class KeyboardModel: ObservableObject {
    @Published var state: KeyboardState = .idle
    @Published var tones: [Tone] = []
    @Published var selectedTone: Tone
    @Published var needsGlobeKey: Bool = false
    @Published var pendingContext: String = ""
    @Published var currentReplies: [String] = []
    @Published var contactName: String? = nil
    @Published var lastInsertedReply: String? = nil
    @Published var hasAnySessions: Bool = false
    @Published var inputMode: KeyboardInputMode = .chat
    @Published var repliesGeneratedInMode: KeyboardInputMode = .chat
    /// Currently selected model for the dev header switcher. Only meaningful in dev mode.
    @Published var selectedDevModel: String = AppGroupService.shared.selectedModel
    var lastEmailText: String? = nil   // email text behind the current replies, for Regenerate
    @Published var isCaptureMode: Bool = false
    @Published var isCollapsed: Bool = false
    @Published var memoryContactName: String? = nil
    @Published var showConsentPrompt: Bool = false
    @Published var detectedScreenshotID: String? = nil   // a new screenshot awaiting the confirm tap
    var captureBaselineScreenshotID: String? = nil        // newest screenshot at moment-of-collapse (dedup)
    @Published var showFullScreenPreviewHint: Bool = false   // iOS 26: likely needs Full-Screen Previews off
    var collapseStartedAt: Date? = nil

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onUndoInsert: (() -> Void)?
    var onEditReply: ((String) -> Void)?
    var retryTrigger: (() -> Void)?
    var onContentHeightChanged: ((CGFloat) -> Void)?
    var onOpenContainingApp: ((String) -> Void)?   // attempt to open the Replr app via a URL scheme

    enum CreditDisplay: Equatable {
        case unlimited
        case count(Int)
    }

    /// Returns .unlimited in dev mode (shows ∞). Returns .count(balance) otherwise.
    var creditDisplay: CreditDisplay {
        if AppGroupService.shared.devMode { return .unlimited }
        return .count(AppGroupService.shared.effectiveCreditBalance)
    }

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    func generateEmailReply() {
        guard case .idle = state else { return }
        let balance = AppGroupService.shared.effectiveCreditBalance
        let required = AppGroupService.shared.creditsRequired
        guard balance >= required else {
            withAnimation(.easeInOut(duration: 0.2)) { state = .paywall }
            return
        }
        guard let emailText = UIPasteboard.general.string,
              !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation { state = .error("No text on clipboard. Copy the email first.") }
            return
        }
        lastEmailText = emailText   // remember for Regenerate
        repliesGeneratedInMode = .email   // a retry-after-error must target the email, not a stale screenshot
        withAnimation(.easeInOut(duration: 0.2)) { state = .loading }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previousContext: String?
            if let contactID = AppGroupService.shared.currentContactID {
                let summaries = AppGroupService.shared.recentSummaries(
                    forContactID: contactID, limit: AppGroupService.shared.memoryDepth)
                previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
            } else {
                previousContext = nil
            }
            do {
                let result = try await ReplyService.shared.generateRepliesFromEmail(
                    emailText: emailText,
                    tone: selectedTone,
                    summary: pendingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : pendingContext,
                    previousContext: previousContext
                )
                let resolved = resolveContact(from: result)
                contactName = resolved.name
                let session = CaptureSession(
                    id: UUID(),
                    timestamp: Date(),
                    thumbnailData: nil,
                    contextHint: pendingContext.isEmpty ? nil : pendingContext,
                    generatedReplies: result.replies,
                    selectedReply: nil,
                    llmSummary: result.summary,
                    contactID: resolved.id,
                    contactName: resolved.name
                )
                if !AppGroupService.shared.devMode {
                    AppGroupService.shared.creditBalance -= required
                }
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
                currentReplies = result.replies
                repliesGeneratedInMode = .email
                hasAnySessions = true
                withAnimation(.easeInOut(duration: 0.2)) { state = .replies(result.replies) }
            } catch {
                withAnimation { state = .error(error.localizedDescription) }
            }
        }
    }

    func selectTone(_ tone: Tone) { selectedTone = tone; onToneChanged?(tone) }
    func selectReply(_ text: String) { onReplySelected?(text) }
    func editReply(_ text: String) { onEditReply?(text) }

    /// True when the panel is in its idle (capture-ready) state — used to arm the screenshot
    /// watcher whenever the keyboard is open, not only after the user taps Start.
    var isIdleState: Bool { if case .idle = state { return true } else { return false } }

    /// User declined the auto-caught screenshot — clear it and advance the baseline so the same
    /// shot won't be re-detected on the next poll.
    func dismissDetectedScreenshot() {
        if let id = detectedScreenshotID { captureBaselineScreenshotID = id }
        detectedScreenshotID = nil
    }

    /// Phase 1 — generate replies from the detected screenshot (mirrors generateEmailReply).
    func generateFromScreenshot() {
        guard let assetID = detectedScreenshotID else { return }
        let required = AppGroupService.shared.creditsRequired
        guard AppGroupService.shared.effectiveCreditBalance >= required else {
            withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = false; state = .paywall }
            return
        }
        let context = pendingContext.trimmingCharacters(in: .whitespacesAndNewlines)
        repliesGeneratedInMode = .chat   // a retry-after-error must target this screenshot, not stale email text
        withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = false; state = .loading }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let image = await PhotosCapture.loadImage(id: assetID) else {
                self.detectedScreenshotID = nil
                withAnimation { self.state = .error("Couldn't read the screenshot. Try again.") }
                return
            }
            // Persist so Regenerate (which reads the App Group screenshot) re-runs THIS screenshot, not a stale one.
            try? AppGroupService.shared.writeScreenshot(image)
            let previousContext: String?
            if let contactID = AppGroupService.shared.currentContactID {
                let summaries = AppGroupService.shared.recentSummaries(
                    forContactID: contactID, limit: AppGroupService.shared.memoryDepth)
                previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
            } else {
                previousContext = nil
            }
            do {
                let result = try await ReplyService.shared.generateReplies(
                    screenshot: image,
                    tone: self.selectedTone,
                    summary: context.isEmpty ? nil : context,
                    previousContext: previousContext
                )
                let resolved = resolveContact(from: result)
                self.contactName = resolved.name
                var session = CaptureSession(
                    id: UUID(), timestamp: Date(), thumbnailData: nil,
                    contextHint: context.isEmpty ? nil : context,
                    generatedReplies: result.replies, selectedReply: nil,
                    llmSummary: result.summary, contactID: resolved.id, contactName: resolved.name
                )
                session.toneName = self.selectedTone.name
                session.previousContext = previousContext
                session.modelUsed = AppGroupService.shared.selectedModel
                session.inputTokens = result.inputTokens
                session.outputTokens = result.outputTokens
                session.costUsd = result.costUsd
                if !AppGroupService.shared.devMode { AppGroupService.shared.creditBalance -= required }
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
                self.currentReplies = result.replies
                self.repliesGeneratedInMode = .chat
                self.hasAnySessions = true
                self.captureBaselineScreenshotID = assetID   // dedup: never reprocess this one
                AppGroupService.shared.recordCapturedScreenshotID(assetID)
                self.detectedScreenshotID = nil
                withAnimation(.easeInOut(duration: 0.2)) { self.state = .replies(result.replies) }
            } catch {
                self.detectedScreenshotID = nil
                withAnimation { self.state = .error(error.localizedDescription) }
            }
        }
    }


    /// Re-runs the SAME input that produced the current replies — email text in email mode,
    /// the saved screenshot in chat mode — so Regenerate works correctly in both.
    func regenerateReplies() {
        let required = AppGroupService.shared.creditsRequired
        guard AppGroupService.shared.effectiveCreditBalance >= required else {
            withAnimation(.easeInOut(duration: 0.2)) { state = .paywall }
            return
        }
        AppGroupService.shared.sessionRegenerateCount += 1   // steer-tip discovery trigger
        // Steer (REPLY DIRECTION) for the regenerate. Prefer a steer the user just
        // typed; otherwise reuse the steer that produced the CURRENT replies — the
        // latest session's contextHint. The compose field is cleared/consumed after
        // the first generation, so `pendingContext` is empty by the time we're here.
        let liveHint = pendingContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedHint = (AppGroupService.shared.loadCaptureSessions().last?.contextHint ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let steer = liveHint.isEmpty ? savedHint : liveHint
        let summary = steer.isEmpty ? nil : steer
        let isEmail = (repliesGeneratedInMode == .email)

        // Resolve the source up front so we can bail before showing loading.
        let emailText = lastEmailText ?? UIPasteboard.general.string
        let image: UIImage? = isEmail ? nil : (try? AppGroupService.shared.readScreenshot())

        if isEmail {
            guard let text = emailText,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                withAnimation { state = .error("No email to regenerate. Copy the email again.") }
                return
            }
        } else if image == nil {
            withAnimation { state = .error("No screenshot saved. Capture again.") }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) { state = .loading }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previousContext: String?
            if let contactID = AppGroupService.shared.currentContactID {
                let summaries = AppGroupService.shared.recentSummaries(
                    forContactID: contactID, limit: AppGroupService.shared.memoryDepth)
                previousContext = summaries.isEmpty ? nil : summaries.joined(separator: "\n")
            } else {
                previousContext = nil
            }
            do {
                let result: ReplyResult
                if isEmail {
                    result = try await ReplyService.shared.generateRepliesFromEmail(
                        emailText: emailText ?? "", tone: self.selectedTone,
                        summary: summary, previousContext: previousContext)
                } else {
                    result = try await ReplyService.shared.generateReplies(
                        screenshot: image!, tone: self.selectedTone,
                        summary: summary, previousContext: previousContext)
                }
                if !AppGroupService.shared.devMode { AppGroupService.shared.creditBalance -= required }
                self.currentReplies = result.replies
                self.repliesGeneratedInMode = isEmail ? .email : .chat
                AppGroupService.shared.saveReplies(result.replies)
                withAnimation(.easeInOut(duration: 0.2)) { self.state = .replies(result.replies) }
            } catch {
                withAnimation { self.state = .error(error.localizedDescription) }
            }
        }
    }

    func regenerate() {
        isCaptureMode = false
        isCollapsed = false
        lastInsertedReply = nil
        contactName = nil
        memoryContactName = nil
        AppGroupService.shared.currentContactID = nil
        AppGroupService.shared.clearCachedReplies()
        currentReplies = []
        withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
    }

    func clearRepliesForCapture() {
        lastInsertedReply = nil
        contactName = nil
        memoryContactName = nil
        AppGroupService.shared.currentContactID = nil
        AppGroupService.shared.clearCachedReplies()
        currentReplies = []
        state = .idle
    }

    func startRenameContact() {
        let name = contactName ?? ""
        let allContacts = AppGroupService.shared.loadContacts()
        let candidates = allContacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(name)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            state = .disambiguate(name: name, candidates: candidates)
        }
    }

    func retryGeneration() {
        // Re-run generation on the last input (saved screenshot in chat mode,
        // email text in email mode) — mirrors Regenerate. The old poll-restart
        // did nothing: the error had already been consumed and no generation was
        // in flight, so no poll branch ever fired and the button looked dead.
        regenerateReplies()
    }
}

// MARK: - Root View

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        ZStack(alignment: .top) {
            // Background is handled by view.backgroundColor in KeyboardViewController (UIKit layer).
            // Do NOT put a greedy SwiftUI Color here — it defeats sizeThatFits measurement.
            if model.isCollapsed {
                CollapsedStripView(model: model).transition(.opacity)
            } else {
                switch model.state {
                case .idle:
                    IdlePanelView(model: model).transition(.opacity)
                case .loading:
                    LoadingPanelView(model: model).transition(.opacity)
                case .replies(let replies):
                    RepliesPanelView(model: model, replies: replies).transition(.opacity)
                case .error(let message):
                    ErrorPanelView(message: message, model: model).transition(.opacity)
                case .disambiguate(let name, let candidates):
                    DisambiguatePanelView(model: model, name: name, candidates: candidates)
                        .transition(.opacity)
                case .paywall:
                    PaywallCardView(model: model).transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isCollapsed)
        .animation(.easeInOut(duration: 0.2), value: stateTag)
        .ignoresSafeArea()
        .onChange(of: model.inputMode) { newMode in
            if case .replies = model.state, model.repliesGeneratedInMode != newMode {
                withAnimation(.easeInOut(duration: 0.2)) { model.state = .idle }
            }
        }
    }

    private var stateTag: Int {
        switch model.state {
        case .idle:         return 0
        case .loading:      return 1
        case .replies:      return 2
        case .error:        return 3
        case .disambiguate: return 4
        case .paywall:      return 5
        }
    }
}

// MARK: - TapGlyph

struct TapGlyph: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ReplrTheme.Color.textSecondary, lineWidth: 1.2)
                .frame(width: 18, height: 24)
            Circle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: 4, height: 4)
                .opacity(pulse ? 1.0 : 0.35)
            Circle()
                .stroke(ReplrTheme.Color.accent, lineWidth: 0.8)
                .frame(width: 9, height: 9)
                .opacity(pulse ? 0.4 : 0.1)
        }
        .frame(width: 22, height: 28)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(ReplrTheme.Motion.pulse) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - CoachmarkBalloon

struct CoachmarkBalloon: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 1)
            Text("① Keyboard's minimised. ② Take a screenshot of the chat.")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(2)
        }
        .foregroundColor(ReplrTheme.Color.onAccent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .fill(ReplrTheme.Color.accent)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(x: 20, y: 5)
        }
        .accessibilityLabel("Coachmark: Keyboard's minimised. Take a screenshot of the chat.")
    }
}

// MARK: - Collapsed Strip

struct CollapsedStripView: View {
    @ObservedObject var model: KeyboardModel
    @State private var showCoachmark: Bool = false

    private let coachmarkKey = Constants.coachmarkSeenKey

    var body: some View {
        VStack(spacing: 0) {
            // Coachmark — first run only
            if showCoachmark {
                CoachmarkBalloon()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .transition(.opacity.animation(ReplrTheme.Motion.coachmark))
            }

            // Pill handle — adaptive: visible on both native light and dark keyboard chrome
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ReplrTheme.Color.textSecondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Capture card — entire card is the tap target. Adapts to the watcher state.
            Button {
                if model.detectedScreenshotID != nil {
                    model.generateFromScreenshot()
                } else {
                    dismissCoachmark()
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
                }
            } label: {
                HStack(spacing: 10) {
                    if model.detectedScreenshotID != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(ReplrTheme.Color.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Screenshot ready")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.accent)
                            Text("Tap to generate replies")
                                .font(.system(size: 11.5))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ReplrTheme.Color.accent)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.accent)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.showFullScreenPreviewHint
                                 ? "Didn't catch that screenshot"
                                 : "Now take a screenshot of the chat")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ReplrTheme.Color.textPrimary)
                            Text(model.showFullScreenPreviewHint
                                 ? "Settings → Screen Capture → turn off Full-Screen Previews"
                                 : "Replr is watching for it…")
                                .font(.system(size: 11.5))
                                .foregroundColor(ReplrTheme.Color.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .background(ReplrTheme.Color.surface)
                .overlay(alignment: .leading) {
                    ReplrTheme.Color.accent.frame(width: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ReplrTheme.Color.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onAppear {
            let defaults = UserDefaults(suiteName: Constants.appGroupID)
            defaults?.synchronize()
            let seen = defaults?.bool(forKey: coachmarkKey) ?? false
            if !seen {
                withAnimation(ReplrTheme.Motion.coachmark) { showCoachmark = true }
            }
        }
        .onDisappear {
            dismissCoachmark()
        }
    }

    private func dismissCoachmark() {
        guard showCoachmark else { return }
        withAnimation(ReplrTheme.Motion.coachmark) { showCoachmark = false }
        let defaults = UserDefaults(suiteName: Constants.appGroupID)
        defaults?.set(true, forKey: coachmarkKey)
        defaults?.synchronize()
    }
}

// MARK: - Mode Segmented Control

struct ModeSegmentedControl: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 0) {
            modeButton(.chat, label: "Chat", icon: "bubble.left.fill")
            ReplrTheme.Color.glassBorder.frame(width: 1, height: 18)
            modeButton(.email, label: "Email", icon: "envelope.fill")
        }
        .background(ReplrTheme.Color.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func modeButton(_ mode: KeyboardInputMode, label: String, icon: String) -> some View {
        let isSelected = model.inputMode == mode
        Button {
            withAnimation(ReplrTheme.Motion.quick) {
                model.inputMode = mode
                if mode == .email, !model.selectedTone.availableInEmail {
                    model.selectedTone = model.tones.first { $0.isEnabled && $0.availableInEmail } ?? model.selectedTone
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isSelected ? ReplrTheme.Color.accentSubtle : Color.clear)
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: isSelected)
    }
}

// MARK: - Tone Row

struct ToneRow: View {
    @ObservedObject var model: KeyboardModel
    var isDimmed: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.tones.filter { tone in
                        guard tone.isEnabled else { return false }
                        return model.inputMode == .email ? tone.availableInEmail : tone.availableInChat
                    }) { tone in
                        Chip(
                            label: tone.name,
                            isSelected: tone.name == model.selectedTone.name,
                            action: { model.selectTone(tone) }
                        )
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 32)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            if model.needsGlobeKey {
                ReplrTheme.Color.glassBorder.frame(width: 0.5, height: 16)
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
        .opacity(isDimmed ? 0.35 : 1.0)
    }
}

// MARK: - Keyboard Header (segmented control + optional tone row)

struct KeyboardHeader: View {
    @ObservedObject var model: KeyboardModel
    var isSegmentedDisabled: Bool = false
    var isToneHidden: Bool = false
    var isToneDimmed: Bool = false
    /// When provided (idle state only), shows a sliders button that opens the how-to overlay.
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let onOpenSettings {
                    Button(action: onOpenSettings) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.accent)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                ModeSegmentedControl(model: model)
                    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                    .allowsHitTesting(!isSegmentedDisabled)
                Spacer(minLength: 8)
                switch model.creditDisplay {
                case .unlimited:
                    // Dev mode: tappable model switcher — all models available.
                    Menu {
                        ForEach(DevModelOption.all) { option in
                            Button {
                                AppGroupService.shared.selectedModel = option.id
                                model.selectedDevModel = option.id
                            } label: {
                                if model.selectedDevModel == option.id {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("∞")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ReplrTheme.Color.accent)
                            Text(DevModelOption.shortLabel(for: model.selectedDevModel))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.accent.opacity(0.7))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(ReplrTheme.Color.accent.opacity(0.55))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                case .count(let n) where n <= 20:
                    CreditCounterBadge(count: n)
                case .count:
                    ReplrMark(size: 16)
                        .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            if !isToneHidden {
                ToneRow(model: model, isDimmed: isToneDimmed)
            }
        }
        .background(ReplrTheme.Color.bg)
    }
}

struct SkeletonLine: View {
    let fraction: CGFloat
    let pulse: Bool
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: ReplrTheme.Color.textPrimary.opacity(0.07), location: 0),
                        .init(color: ReplrTheme.Color.textPrimary.opacity(0.16), location: shimmer ? 0.5 : 0.15),
                        .init(color: ReplrTheme.Color.textPrimary.opacity(0.07), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(x: fraction, anchor: .leading)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
                    .delay(pulse ? 0.3 : 0)
                ) { shimmer = true }
            }
    }
}

// MARK: - Paywall Card (keyboard compact)

struct PaywallCardView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isSegmentedDisabled: true, isToneHidden: true)
            Spacer()
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Your 10 free replies are up.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ReplrTheme.Color.textPrimary)
                    Text("Unlock Pro to keep going.")
                        .font(.system(size: 13))
                        .foregroundStyle(ReplrTheme.Color.textSecondary)
                }

                // The upgrade is purchased in the app, so this is a single, honest step:
                // open Replr. A SwiftUI Link is the only thing that opens the containing app
                // from a keyboard extension on iOS 18+ (same approach as the idle-card CTAs).
                if let url = URL(string: "replr://paywall") {
                    Link(destination: url) {
                        Text("Open Replr →")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ReplrTheme.Color.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                                    .fill(ReplrTheme.Color.accent)
                            )
                            .shadow(color: ReplrTheme.Color.accent.opacity(
                                colorScheme == .dark ? 0.55 : 0), radius: 14, x: 0, y: 5)
                    }
                }

                Text("Switch to the Replr app to finish — your upgrade is waiting there.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.accent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }
}

// MARK: - Credit Counter Badge

struct CreditCounterBadge: View {
    let count: Int

    private var color: Color {
        if count <= 3 { return ReplrTheme.Color.danger }
        if count <= 10 { return Color(red: 0.85, green: 0.60, blue: 0.10) }
        return ReplrTheme.Color.textSecondary
    }

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - PhotosCapture (Phase 1 — screenshot capture; run() kept for dev spike button)
// Inlined here because the keyboard target does not auto-include new files.

enum PhotosCapture {
    /// localIdentifier of the newest screenshot, or nil if none / not authorized. No image load.
    static func latestScreenshotID() -> String? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        return PHAsset.fetchAssets(with: .image, options: opts).firstObject?.localIdentifier
    }

    /// Loads the full UIImage for a screenshot localIdentifier.
    static func loadImage(id: String) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        return await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = false
            opts.isSynchronous = false
            opts.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                if let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    cont.resume(returning: image)
                } else if (info?[PHImageErrorKey] as? Error) != nil {
                    cont.resume(returning: nil)
                }
                // else: degraded frame — wait for the full-quality delivery
            }
        }
    }
}


// MARK: - Dev model switcher

/// Lightweight model descriptor for the dev model Menu in the keyboard header.
/// Dev-only — never shown to production users. Mirrors ReplrModel from the app target
/// but avoids a cross-target import by re-declaring only what the keyboard needs.
private struct DevModelOption: Identifiable {
    let id: String       // matches the API model identifier
    let label: String    // short display label shown in the Menu

    static let all: [DevModelOption] = [
        DevModelOption(id: "claude-sonnet-4-6",      label: "Sonnet 4.6"),
        DevModelOption(id: "gpt-5.4",               label: "GPT-5.4"),
        DevModelOption(id: "claude-opus-4-6",        label: "Opus 4.6 ★"),
        DevModelOption(id: "gpt-5.5",               label: "GPT-5.5 ★"),
        DevModelOption(id: "gemini-3.1-pro-preview", label: "Gemini Pro · High ★"),
        DevModelOption(id: "gemini-3.1-pro-low",     label: "Gemini Pro · Low"),
        DevModelOption(id: "gemini-3-flash-preview", label: "Gemini Flash"),
        DevModelOption(id: "gemini-3.5-flash",       label: "Gemini 3.5 Flash"),
        DevModelOption(id: "gemini-3.1-flash-lite",  label: "Gemini 3.1 Flash Lite"),
        DevModelOption(id: "gemini-2.5-pro",         label: "Gemini 2.5 Pro"),
        DevModelOption(id: "grok-4",                label: "Grok 4"),
        DevModelOption(id: "grok-4.3",              label: "Grok 4.3"),
        DevModelOption(id: "gpt-5.4-mini",          label: "GPT-5.4 Mini"),
    ]

    static func shortLabel(for id: String) -> String {
        all.first { $0.id == id }?.label ?? id
    }
}
