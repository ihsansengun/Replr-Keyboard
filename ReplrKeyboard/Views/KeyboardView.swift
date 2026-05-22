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
    @Published var isCaptureMode: Bool = false
    @Published var isCollapsed: Bool = false

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNewContact: ((String) -> Void)?
    var onUndoInsert: (() -> Void)?
    var onEditReply: ((String) -> Void)?
    var retryTrigger: (() -> Void)?

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    func generateEmailReply() {
        guard case .idle = state else { return }
        guard let emailText = UIPasteboard.general.string,
              !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation { state = .error("No text on clipboard. Copy the email first.") }
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) { state = .loading }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let txID = UserDefaults(suiteName: Constants.appGroupID)?
                .string(forKey: Constants.transactionIDKey)
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
                    previousContext: previousContext,
                    model: "claude",
                    transactionId: txID
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
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
                currentReplies = result.replies
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
        AppGroupService.shared.clearCachedReplies()
        currentReplies = []
        withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
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
        ZStack {
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
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isCollapsed)
        .animation(.easeInOut(duration: 0.2), value: stateTag)
        .background(ReplrTheme.Color.bg)
        .ignoresSafeArea()
    }

    private var stateTag: Int {
        switch model.state {
        case .idle:         return 0
        case .loading:      return 1
        case .replies:      return 2
        case .error:        return 3
        case .disambiguate: return 4
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
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
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
            Text("① Keyboard's minimised. ② Double-tap the back.")
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
        .accessibilityLabel("Coachmark: Keyboard's minimised. Double-tap the back.")
    }
}

// MARK: - Collapsed Strip

struct CollapsedStripView: View {
    @ObservedObject var model: KeyboardModel
    @State private var showCoachmark: Bool = false

    private let coachmarkKey = "keyboard.coachmarkSeen"

    var body: some View {
        VStack(spacing: 0) {
            // Coachmark — first run only, sits above the capture card
            if showCoachmark {
                CoachmarkBalloon()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .transition(.opacity.animation(ReplrTheme.Motion.coachmark))
            }

            // Capture card
            HStack(spacing: 10) {
                TapGlyph()

                VStack(alignment: .leading, spacing: 1) {
                    Text("Double-tap the back of your phone")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("to capture this chat")
                        .font(.system(size: 11.5))
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }

                Spacer()

                Button {
                    dismissCoachmark()
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
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
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ReplrTheme.Color.bg)
        .onAppear {
            let seen = UserDefaults(suiteName: Constants.appGroupID)?
                .bool(forKey: coachmarkKey) ?? false
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
        UserDefaults(suiteName: Constants.appGroupID)?
            .set(true, forKey: coachmarkKey)
    }
}

// MARK: - Mode Segmented Control

struct ModeSegmentedControl: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 2) {
            segmentBtn(mode: .chat,  label: "Chat")
            segmentBtn(mode: .email, label: "Email")
        }
        .padding(3)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                .stroke(ReplrTheme.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentBtn(mode: KeyboardInputMode, label: String) -> some View {
        let isActive = model.inputMode == mode
        Button {
            guard model.inputMode != mode else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                if case .replies = model.state { model.regenerate() }
                if mode == .email, model.selectedTone.name == "Dating" {
                    model.selectedTone = model.tones.first { $0.name != "Dating" } ?? model.selectedTone
                }
                model.inputMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? ReplrTheme.Color.textPrimary : ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? ReplrTheme.Color.surfaceRaised : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Tone Row

struct ToneRow: View {
    @ObservedObject var model: KeyboardModel
    var isDimmed: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(model.tones.filter { model.inputMode == .chat || $0.name != "Dating" }) { tone in
                        Chip(
                            label: tone.name,
                            isSelected: tone.name == model.selectedTone.name,
                            action: { model.selectTone(tone) }
                        )
                    }
                }
                .padding(.leading, 8)
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
                ReplrTheme.Color.borderStrong.frame(width: 0.5, height: 16)
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .overlay(alignment: .top) { ReplrTheme.Color.border.frame(height: 0.5) }
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
                ReplrMark(size: 14)
                    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if !isToneHidden {
                ToneRow(model: model, isDimmed: isToneDimmed)
            }
        }
        .background(ReplrTheme.Color.bg)
        .overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }
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

