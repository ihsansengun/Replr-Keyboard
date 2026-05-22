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

// MARK: - Collapsed Strip

struct CollapsedStripView: View {
    @ObservedObject var model: KeyboardModel
    @State private var phoneScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            // Accent left edge
            ReplrTheme.Color.accent
                .frame(width: 3)

            HStack(spacing: 10) {
                // Animated phone glyph
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ReplrTheme.Color.accent)
                    .scaleEffect(phoneScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                        ) { phoneScale = 0.82 }
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Double-tap the back of your phone")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("to capture this chat")
                        .font(.system(size: 11))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }

                Spacer()

                // Cancel — return to idle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.isCollapsed = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReplrTheme.Color.surface)
    }
}

// MARK: - Mode Segmented Control

struct ModeSegmentedControl: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 2) {
            segmentBtn(mode: .chat,  iconName: "message.fill",  label: "Chat")
            segmentBtn(mode: .email, iconName: "envelope.fill", label: "Email")
        }
        .padding(3)
        .background(ReplrTheme.Color.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 7)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func segmentBtn(mode: KeyboardInputMode, iconName: String, label: String) -> some View {
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
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isActive ? ReplrTheme.Color.textPrimary : ReplrTheme.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
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
            ModeSegmentedControl(model: model)
                .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                .allowsHitTesting(!isSegmentedDisabled)
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

