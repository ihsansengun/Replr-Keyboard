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

private struct IntentIcon: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2, cy = h / 2
            var path = Path()
            // Outer ring
            path.addEllipse(in: CGRect(x: cx - w * 0.44, y: cy - h * 0.44,
                                       width: w * 0.88, height: h * 0.88))
            // Middle ring
            path.addEllipse(in: CGRect(x: cx - w * 0.27, y: cy - h * 0.27,
                                       width: w * 0.54, height: h * 0.54))
            // Centre dot
            path.addEllipse(in: CGRect(x: cx - w * 0.10, y: cy - h * 0.10,
                                       width: w * 0.20, height: h * 0.20))
            ctx.stroke(path, with: .color(color),
                      style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
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

enum KeyboardInputMode { case chat, email }

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
    @Published var intentHint: String? = nil

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onUseAsContext: (() -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNewContact: ((String) -> Void)?
    var onUndoInsert: (() -> Void)?
    var onEditReply: ((String) -> Void)?
    var retryTrigger: (() -> Void)?
    var readTextProxy: (() -> String?)?   // reads documentContextBeforeInput from VC
    var onDeleteTextProxy: (() -> Void)?  // deletes draft from text proxy after intent capture

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    // MARK: - Input

    func captureIntent() {
        // Reads whatever the user typed in the host app's text field and saves it as intent
        guard let raw = readTextProxy?(),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        intentHint = trimmed
        AppGroupService.shared.saveIntentHint(trimmed)
        pendingContext = ""
        onDeleteTextProxy?()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func clearIntent() {
        AppGroupService.shared.saveIntentHint(nil)
        intentHint = nil
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
                    summary: intentHint,
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
                    contextHint: intentHint,
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

    func useAsContext() {
        onUseAsContext?()
        pendingContext = ""
    }

    func selectTone(_ tone: Tone) { selectedTone = tone; onToneChanged?(tone) }
    func selectReply(_ text: String) { onReplySelected?(text) }
    func editReply(_ text: String) { onEditReply?(text) }
    func regenerate() {
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
                onSend: { model.selectReply($0) },
                onEdit: { model.editReply($0) }
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
                .background(isSelected ? KBColors.accent : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Keyboard Colors

struct KBColors {
    let alpha: Color      // letter key face
    let fn: Color         // function key face
    let letterText: Color // letter key label
    let fnText: Color     // fn key label / icon
    let subtext: Color    // space bar label
    let shadow: Color     // key bottom shadow
    let bg: Color         // QWERTY area background

    static func from(_ cs: ColorScheme) -> KBColors {
        KBColors(
            alpha:      Color(red: 0.929, green: 0.898, blue: 0.816), // #EDE5D0 cream
            fn:         Color(red: 0.420, green: 0.376, blue: 0.314), // #6B6050 taupe
            letterText: Color(red: 0.102, green: 0.078, blue: 0.031), // #1A1408 dark amber
            fnText:     Color(red: 0.929, green: 0.898, blue: 0.816), // #EDE5D0 cream
            subtext:    Color(red: 0.929, green: 0.898, blue: 0.816).opacity(0.65),
            shadow:     Color(red: 0.039, green: 0.031, blue: 0.012), // #0A0803
            bg:         Color(red: 0.133, green: 0.114, blue: 0.078)  // #221D14
        )
    }

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
    static let surfaceActive = Color(red: 0.180, green: 0.145, blue: 0.094)
}

// MARK: - Disambiguate View

struct DisambiguateView: View {
    let name: String
    let candidates: [Contact]
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNew: ((String) -> Void)?

    private let thumbnails: [UUID: UIImage]

    init(name: String, candidates: [Contact],
         onSelectContact: ((Contact) -> Void)? = nil,
         onCreateNew: ((String) -> Void)? = nil) {
        self.name = name
        self.candidates = candidates
        self.onSelectContact = onSelectContact
        self.onCreateNew = onCreateNew
        var map: [UUID: UIImage] = [:]
        for contact in candidates {
            if let data = AppGroupService.shared.sessions(forContactID: contact.id)
                    .last?.thumbnailData,
               let img = UIImage(data: data) {
                map[contact.id] = img
            }
        }
        self.thumbnails = map
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Which \(name)?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KBColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(KBColors.deep)

            KBColors.borderHair.frame(height: 0.5)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { contact in
                        Button { onSelectContact?(contact) } label: {
                            HStack(spacing: 10) {
                                thumbnailView(for: contact)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(KBColors.textPrimary)
                                    if let summary = AppGroupService.shared
                                            .recentSummaries(forContactID: contact.id, limit: 1).first {
                                        Text(summary)
                                            .font(.system(size: 11))
                                            .foregroundColor(KBColors.textDim)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .background(KBColors.surface)
                        .overlay(alignment: .bottom) {
                            KBColors.borderHair.frame(height: 0.5)
                        }
                    }

                    Button { onCreateNew?(name) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("New contact named \(name)")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(KBColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(KBColors.background)
    }

    @ViewBuilder
    private func thumbnailView(for contact: Contact) -> some View {
        if let img = thumbnails[contact.id] {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(KBColors.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 12))
                        .foregroundColor(KBColors.textDim)
                )
        }
    }
}

// MARK: - Replr Strip (mode row + tone row = 68px)

struct ReplrStrip: View {
    @ObservedObject var model: KeyboardModel

    private enum IntentTabState: Equatable { case empty, ready, captured }

    private var intentTabState: IntentTabState {
        if model.intentHint != nil { return .captured }
        if !model.pendingContext.isEmpty { return .ready }
        return .empty
    }

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

                intentTab

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

    // MARK: - Intent Tab

    @ViewBuilder
    private var intentTab: some View {
        let faceColor: Color = intentTabState == .captured
            ? Color(red: 0.929, green: 0.898, blue: 0.816)   // cream when captured
            : Color(red: 0.310, green: 0.259, blue: 0.180)   // vintage otherwise
        let iconColor: Color = intentTabState == .captured
            ? Color(red: 0.102, green: 0.078, blue: 0.031)   // dark amber when captured
            : Color(red: 0.929, green: 0.898, blue: 0.816).opacity(0.75)
        let borderColor: Color = intentTabState == .ready
            ? KBColors.accent.opacity(0.8) : Color.clear

        Button {
            switch intentTabState {
            case .empty:    break
            case .ready:    model.captureIntent()
            case .captured: model.clearIntent()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                IntentIcon(color: iconColor)
                    .frame(width: 18, height: 14)
                    .frame(width: 34, height: 26)

                if intentTabState == .captured {
                    Circle()
                        .fill(Color(red: 0.102, green: 0.078, blue: 0.031))
                        .frame(width: 5, height: 5)
                        .offset(x: -2, y: 2)
                        .transition(.opacity)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(faceColor)
                    .shadow(color: Color(red: 0.039, green: 0.031, blue: 0.012),
                            radius: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(intentTabState == .empty ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: intentTabState)
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
                    Text(model.inputMode == .email ? "↑ Generate from clipboard" : "↑ Capture replies")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(model.inputMode == .email
                                         ? KBColors.accent.opacity(0.15)
                                         : KBColors.textDim.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)

                case .idle where !model.hasAnySessions && model.inputMode == .chat:
                    Text("Set up triple-tap →")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 20)
                        .padding(.leading, 4)

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
                    } else {
                        Text("↑ Capture replies")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(KBColors.textDim)
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                            .background(KBColors.textDim.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(KBColors.textDim.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(white: pulse ? 0.18 : 0.13))
            .frame(height: 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(x: fraction, anchor: .leading)
    }
}

