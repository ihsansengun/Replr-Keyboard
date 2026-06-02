import SwiftUI
import Combine
import UIKit

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
    @Published var isCaptureMode: Bool = false
    @Published var isCollapsed: Bool = false
    @Published var memoryContactName: String? = nil
    @Published var showConsentPrompt: Bool = false

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onUndoInsert: (() -> Void)?
    var onEditReply: ((String) -> Void)?
    var retryTrigger: (() -> Void)?
    var onContentHeightChanged: ((CGFloat) -> Void)?

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
        retryTrigger?()
    }
}

// MARK: - Root View

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        ZStack(alignment: .top) {
            // Solid bg only when expanded — collapsed lets native iOS chrome show through
            if !model.isCollapsed {
                ReplrTheme.Color.bg
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
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
            Text("① Keyboard's minimised. ② Triple-tap the back.")
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
        .accessibilityLabel("Coachmark: Keyboard's minimised. Triple-tap the back.")
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

            // Capture card — entire card is the tap target
            Button {
                dismissCoachmark()
                withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
            } label: {
                HStack(spacing: 10) {
                    TapGlyph()

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Triple-tap the back of your phone")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(ReplrTheme.Color.textPrimary)
                        Text("to capture this chat")
                            .font(.system(size: 11.5))
                            .foregroundColor(ReplrTheme.Color.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 36)
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
                if mode == .email, model.selectedTone.name == "Dating" {
                    model.selectedTone = model.tones.first { $0.name != "Dating" } ?? model.selectedTone
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
                    ForEach(model.tones.filter { $0.isEnabled && (model.inputMode == .chat || $0.name != "Dating") }) { tone in
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ModeSegmentedControl(model: model)
                    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                    .allowsHitTesting(!isSegmentedDisabled)
                Spacer()
                switch model.creditDisplay {
                case .unlimited:
                    HStack(spacing: 4) {
                        Text("∞")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ReplrTheme.Color.accent)
                        Text(AppGroupService.shared.selectedModelShortLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ReplrTheme.Color.accent.opacity(0.7))
                    }
                case .count(let n) where n <= 20:
                    CreditCounterBadge(count: n)
                case .count:
                    ReplrMark(size: 16)
                        .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
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
                        .init(color: ReplrTheme.Color.surface, location: 0),
                        .init(color: ReplrTheme.Color.surfaceRaised, location: shimmer ? 0.5 : 0.15),
                        .init(color: ReplrTheme.Color.surface, location: 1),
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

                Button {
                    openPaywallInApp()
                } label: {
                    Text("Unlock Pro in Replr")
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
                .buttonStyle(.plain)

                Text("$9.99/mo · $59.99/yr")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.bg)
    }

    private func openPaywallInApp() {
        AppGroupService.shared.paywallRequested = true
        guard let url = URL(string: "replr://paywall") else { return }
        // extensionContext?.open is restricted in keyboard extensions on most iOS versions.
        // The App Group flag ensures companion app shows PaywallView on next foreground.
        _ = url
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

