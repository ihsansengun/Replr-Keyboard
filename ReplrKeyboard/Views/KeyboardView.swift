import SwiftUI
import Combine
import UIKit

// MARK: - Custom Mode Icons

private struct ChatIcon: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var path = Path()
            // Top wave — represents one side of a conversation
            path.move(to: CGPoint(x: 0, y: h * 0.30))
            path.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.30),
                         control1: CGPoint(x: w * 0.15, y: h * 0.05),
                         control2: CGPoint(x: w * 0.35, y: h * 0.55))
            path.addCurve(to: CGPoint(x: w, y: h * 0.30),
                         control1: CGPoint(x: w * 0.65, y: h * 0.05),
                         control2: CGPoint(x: w * 0.85, y: h * 0.55))
            // Bottom wave — the other side, phase-shifted
            path.move(to: CGPoint(x: 0, y: h * 0.72))
            path.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.72),
                         control1: CGPoint(x: w * 0.15, y: h * 0.47),
                         control2: CGPoint(x: w * 0.35, y: h * 0.97))
            path.addCurve(to: CGPoint(x: w, y: h * 0.72),
                         control1: CGPoint(x: w * 0.65, y: h * 0.47),
                         control2: CGPoint(x: w * 0.85, y: h * 0.97))
            ctx.stroke(path, with: .color(color),
                      style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

private struct EmailIcon: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var path = Path()
            // Paper airplane body
            path.move(to: CGPoint(x: w * 0.92, y: h * 0.08))
            path.addLine(to: CGPoint(x: w * 0.04, y: h * 0.52))
            path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.60))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.08))
            // Fold crease
            path.move(to: CGPoint(x: w * 0.36, y: h * 0.60))
            path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.40))
            ctx.stroke(path, with: .color(color),
                      style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
    }
}

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
                loadingPanel.transition(.opacity)
            case .replies(let replies):
                repliesPanel(replies).transition(.opacity)
            case .error(let message):
                errorPanel(message).transition(.opacity)
            case .disambiguate(let name, let candidates):
                VStack(spacing: 0) {
                    ReplrStrip(model: model)
                    DisambiguateView(
                        name: name,
                        candidates: candidates,
                        onSelectContact: { model.onSelectContact?($0) },
                        onCreateNew: { model.onCreateNewContact?($0) }
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stateTag)
        .background(KBColors.background)
        .ignoresSafeArea()
    }

    private var loadingPanel: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    SkeletonLine(fraction: [0.75, 0.9, 0.6][i], pulse: i == 1)
                }
            }
            .padding(10)
            Spacer(minLength: 0)
        }
    }

    private func repliesPanel(_ replies: [String]) -> some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            if let name = model.contactName {
                contactChip(name)
                KBColors.borderHair.frame(height: 0.5)
            }
            ReplyListView(
                replies: replies,
                lastInsertedReply: model.lastInsertedReply,
                onSend: { model.selectReply($0) },
                onEdit: { model.editReply($0) },
                onUndo: { model.onUndoInsert?() }
            )
        }
    }

    private func contactChip(_ name: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "person.fill").font(.system(size: 9))
            Text(name).font(.system(size: 12)).lineLimit(1)
        }
        .foregroundColor(KBColors.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(KBColors.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button { model.retryGeneration() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                        Text("Retry").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(KBColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(KBColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(KBColors.borderDim, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                .padding(.horizontal, 9).padding(.vertical, 3)
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
        .padding(.top, 7)
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
            .padding(.vertical, 7)
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
        .frame(height: 30)
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

// MARK: - Replr Strip (mode row + tone row = 68px)

struct ReplrStrip: View {
    @ObservedObject var model: KeyboardModel

    private var canSwitchMode: Bool {
        switch model.state {
        case .idle, .loading, .error, .replies: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Mode row ──────────────────────────────────────────────────
            HStack(spacing: 3) {
                modeTab(isActive: model.inputMode == .chat) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        model.inputMode = .chat
                    }
                } icon: { color in
                    ChatIcon(color: color)
                }
                .disabled(!canSwitchMode)

                modeTab(isActive: model.inputMode == .email) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        if model.selectedTone.name == "Dating" {
                            model.selectedTone = model.tones.first { $0.name != "Dating" } ?? model.selectedTone
                        }
                        model.inputMode = .email
                    }
                } icon: { color in
                    EmailIcon(color: color)
                }
                .disabled(!canSwitchMode)

                ctaButton
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(height: 36)

            KBColors.borderHair.frame(height: 0.5)

            // ── Tone row ──────────────────────────────────────────────────
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
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 32)
        }
        .background(KBColors.deep)
        .overlay(alignment: .bottom) { KBColors.borderHair.frame(height: 0.5) }
    }

    // MARK: - Mode Tab

    @ViewBuilder
    private func modeTab<Icon: View>(
        isActive: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: (Color) -> Icon
    ) -> some View {
        let faceColor  = isActive
            ? Color(red: 0.929, green: 0.898, blue: 0.816)   // activeFace — cream
            : Color(red: 0.310, green: 0.259, blue: 0.180)   // vintageFace — dark warm brown
        let iconColor: Color = isActive
            ? Color(red: 0.102, green: 0.078, blue: 0.031)   // activeText — dark amber
            : Color(red: 0.929, green: 0.898, blue: 0.816).opacity(0.75)  // inactiveText

        Button(action: action) {
            icon(iconColor)
                .frame(width: 18, height: 14)
                .frame(width: 34, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(faceColor)
                        .shadow(color: Color(red: 0.039, green: 0.031, blue: 0.012),
                                radius: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Button (fills remaining width)

    @ViewBuilder
    private var ctaButton: some View {
        Group {
            if model.lastInsertedReply != nil {
                Button { model.onUndoInsert?() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .medium))
                        Text("Undo")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(KBColors.accentFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .background(KBColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))

            } else {
                switch model.state {
                case .loading:
                    HStack(spacing: 5) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.55)
                            .tint(KBColors.accent)
                        Text("Generating…")
                            .font(.system(size: 11))
                            .foregroundColor(KBColors.accent.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20)
                    .padding(.leading, 4)

                case .error:
                    Button { model.retryGeneration() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 9))
                            Text("Failed · Retry")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(KBColors.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 20)
                        .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)

                case .replies:
                    if model.inputMode == .email {
                        Text("↑ Generate from clipboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(KBColors.accent.opacity(0.15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                    } else {
                        Color.clear.frame(maxWidth: .infinity).frame(height: 20)
                    }

                default:
                    if model.inputMode == .email {
                        Button { model.generateEmailReply() } label: {
                            Text("↑ Generate from clipboard")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(KBColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 20)
                                .background(KBColors.accent.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(KBColors.accent.opacity(0.38), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if !model.pendingContext.isEmpty {
                        Text(model.pendingContext)
                            .font(.system(size: 11))
                            .foregroundColor(KBColors.textDim)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 20)
                            .padding(.leading, 4)
                    } else {
                        Color.clear.frame(maxWidth: .infinity).frame(height: 20)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.lastInsertedReply == nil)
        .animation(.easeInOut(duration: 0.15), value: ctaStateTag)
    }

    private var ctaStateTag: Int {
        switch model.state {
        case .idle:    return 0
        case .loading: return 1
        case .error:   return 2
        case .replies: return 3
        default:       return 4
        }
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

