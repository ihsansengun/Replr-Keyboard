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

enum KeyboardInputMode: Equatable { case chat, email }

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
        lastInsertedReply = nil
        AppGroupService.shared.clearCachedReplies()
        currentReplies = []
        withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
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
        .animation(.easeInOut(duration: 0.2), value: stateTag)
        .background(KBColors.background)
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

// MARK: - Tone Pill

struct TonePill: View {
    let name: String; let isSelected: Bool; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? KBColors.background : KBColors.textDim)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(isSelected ? KBColors.accent : KBColors.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Keyboard Colors

struct KBColors {
    // MARK: - Design tokens

    // Accent — mustard yellow
    static let accent       = Color(red: 0.831, green: 0.627, blue: 0.090) // #D4A017
    static let accentFg     = Color(red: 0.071, green: 0.055, blue: 0.000) // #120E00
    static let accentShadow = Color(red: 0.478, green: 0.353, blue: 0.000) // #7A5A00
    static let accentSubtle = Color(red: 0.831, green: 0.627, blue: 0.090, opacity: 0.50)
    static let accentBg     = Color(red: 0.831, green: 0.627, blue: 0.090, opacity: 0.12)
    static let accentBgBorder = Color(red: 0.831, green: 0.627, blue: 0.090, opacity: 0.38)

    // Shell backgrounds
    static let background = Color(red: 0.090, green: 0.071, blue: 0.035) // #171209 keyboard shell
    static let deep       = Color(red: 0.118, green: 0.098, blue: 0.071) // #1E1912 strip rows
    static let surface    = Color(red: 0.141, green: 0.118, blue: 0.075) // #241E13 card surfaces

    // Borders + text
    static let borderHair  = Color(red: 0.180, green: 0.145, blue: 0.094) // #2E2518
    static let borderDim   = Color(red: 0.250, green: 0.200, blue: 0.140)
    static let textPrimary = Color(red: 0.929, green: 0.898, blue: 0.816) // #EDE5D0
    static let textDim     = Color(red: 0.420, green: 0.376, blue: 0.314) // #6B6050
    static let textGhost   = Color(red: 0.250, green: 0.200, blue: 0.140)
    static let segmentedBg = Color(red: 0.165, green: 0.125, blue: 0.063) // #2a2010
    static let sentCard    = Color(red: 0.102, green: 0.102, blue: 0.063) // #1a1a10
    static let undoBtnBg   = Color(red: 0.227, green: 0.165, blue: 0.000) // #3a2a00
    static let skeletonHighlight = Color(red: 0.227, green: 0.188, blue: 0.094) // #3a3018
    static let surfaceActive = Color(red: 0.180, green: 0.145, blue: 0.094)
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
        .background(KBColors.segmentedBg)
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
            .foregroundColor(isActive ? KBColors.accentFg : KBColors.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? KBColors.accent : Color.clear)
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
                        TonePill(
                            name: tone.name,
                            isSelected: tone.name == model.selectedTone.name,
                            action: { model.selectTone(tone) }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            if model.needsGlobeKey {
                KBColors.borderDim.frame(width: 0.5, height: 16)
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .overlay(alignment: .top) { KBColors.borderHair.frame(height: 0.5) }
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
        .background(KBColors.deep)
        .overlay(alignment: .bottom) { KBColors.borderHair.frame(height: 0.5) }
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
                        .init(color: KBColors.segmentedBg, location: 0),
                        .init(color: KBColors.skeletonHighlight, location: shimmer ? 0.5 : 0.15),
                        .init(color: KBColors.segmentedBg, location: 1),
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

