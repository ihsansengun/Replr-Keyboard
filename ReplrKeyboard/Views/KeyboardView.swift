import SwiftUI
import Combine
import UIKit

// MARK: - State

enum KeyboardState: Equatable {
    case idle
    case collapsed
    case loading
    case replies([String])
    case editReply(String)
    case error(String)
    case editContact(String)                                // current name pre-filled
    case disambiguate(name: String, candidates: [Contact]) // same-name contact picker
    case editIntent                                         // intent hint text entry
}

enum KBMode { case alpha, numeric }

enum KeyboardInputMode { case chat, email }

// MARK: - Model

@MainActor
final class KeyboardModel: ObservableObject {
    @Published var state: KeyboardState = .idle
    @Published var tones: [Tone] = []
    @Published var selectedTone: Tone
    @Published var needsGlobeKey: Bool = false
    @Published var pendingContext: String = ""
    @Published var inputText: String = ""
    @Published var isShifted: Bool = false
    @Published var kbMode: KBMode = .alpha
    @Published var currentReplies: [String] = []
    @Published var contactName: String? = nil
    @Published var lastInsertedReply: String? = nil
    @Published var hasAnySessions: Bool = false
    @Published var inputMode: KeyboardInputMode = .chat
    @Published var intentHint: String? = nil

    var onReplySelected: ((String) -> Void)?
    var onToneChanged: ((Tone) -> Void)?
    var onSwitchKeyboard: (() -> Void)?
    var onTypeChar: ((String) -> Void)?
    var onDeleteChar: (() -> Void)?
    var onSpaceChar: (() -> Void)?
    var onReturnChar: (() -> Void)?
    var onUseAsContext: (() -> Void)?
    var onConfirmContact: ((String) -> Void)?
    var onDifferentPerson: ((String) -> Void)?
    var onSelectContact: ((Contact) -> Void)?
    var onCreateNewContact: ((String) -> Void)?
    var onUndoInsert: (() -> Void)?
    var retryTrigger: (() -> Void)?
    var readTextProxy: (() -> String?)?   // reads documentContextBeforeInput from VC

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    // MARK: - Input

    func type(_ char: String) {
        let out = isShifted ? char.uppercased() : char
        switch state {
        case .editReply, .editContact, .editIntent: inputText += out
        default: onTypeChar?(out)
        }
        if isShifted, kbMode == .alpha { isShifted = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func backspace() {
        switch state {
        case .editReply, .editContact, .editIntent:
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
        default:
            onDeleteChar?()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func space() {
        switch state {
        case .editReply, .editContact, .editIntent: inputText += " "
        default: onSpaceChar?()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func toggleShift() { isShifted.toggle() }

    func toggleMode() { kbMode = kbMode == .alpha ? .numeric : .alpha }

    func confirmInput() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch state {
        case .editReply:
            if !inputText.isEmpty { onReplySelected?(inputText) }
            withAnimation(.easeInOut(duration: 0.18)) { state = .idle }
        case .editContact:
            if !inputText.isEmpty { onConfirmContact?(inputText) }
        case .editIntent:
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            intentHint = trimmed.isEmpty ? nil : trimmed
            AppGroupService.shared.saveIntentHint(trimmed.isEmpty ? nil : trimmed)
            withAnimation(.easeInOut(duration: 0.18)) { state = .idle }
        default:
            onReturnChar?()
        }
    }

    func cancelInput() {
        withAnimation(.easeInOut(duration: 0.18)) {
            switch state {
            case .editReply, .editContact, .editIntent:
                if !currentReplies.isEmpty {
                    state = .replies(currentReplies)
                } else {
                    state = .idle
                }
            default:
                state = .idle
            }
        }
    }

    func enterEditReply(_ text: String) {
        inputText = text; isShifted = false; kbMode = .alpha
        withAnimation(.easeInOut(duration: 0.18)) { state = .editReply(text) }
    }

    func enterEditContact(_ name: String) {
        inputText = name; isShifted = false; kbMode = .alpha
        withAnimation(.easeInOut(duration: 0.18)) { state = .editContact(name) }
    }

    func captureIntent() {
        // Reads whatever the user typed in the host app's text field and saves it as intent
        guard let raw = readTextProxy?(),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        intentHint = trimmed
        AppGroupService.shared.saveIntentHint(trimmed)
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

    func collapse() {
        withAnimation(.easeInOut(duration: 0.2)) { state = .collapsed }
    }

    func useAsContext() {
        onUseAsContext?()
        pendingContext = ""
        collapse()
    }

    func selectTone(_ tone: Tone) { selectedTone = tone; onToneChanged?(tone) }
    func selectReply(_ text: String) { onReplySelected?(text) }
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

    private var showToneBar: Bool {
        switch model.state {
        case .error, .loading: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            contentArea.frame(maxWidth: .infinity, maxHeight: .infinity)
            if showToneBar { toneBar }
        }
        .background(KBColors.background)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack {
            switch model.state {
            case .idle:
                IdleWithKeyboard(model: model).transition(.opacity)
            case .collapsed:
                CollapsedBar(model: model).transition(.opacity)
            case .loading:
                IdleWithKeyboard(model: model).transition(.opacity)
            case .replies(let replies):
                VStack(spacing: 0) {
                    ReplrStrip(model: model)
                    if let name = model.contactName {
                        Button { model.enterEditContact(name) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))
                                Text(name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(KBColors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        KBColors.borderHair.frame(height: 0.5)
                    }
                    ReplyCarousel(replies: replies,
                                  onSelect: { model.selectReply($0) })
                }
                .transition(.opacity)
            case .editReply:
                // Edit inline removed — unreachable, guard as fallback
                IdleWithKeyboard(model: model).transition(.opacity)
            case .error:
                IdleWithKeyboard(model: model).transition(.opacity)
            case .editContact:
                EditContactView(model: model).transition(.opacity)
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
            case .editIntent:
                // Unreachable — intent capture now reads from text proxy
                IdleWithKeyboard(model: model).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stateTag)
    }

    private var toneBar: some View {
        HStack(spacing: 0) {
            if model.needsGlobeKey {
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(model.tones) { tone in
                        TonePill(name: tone.name,
                                 isSelected: tone.name == model.selectedTone.name,
                                 action: { model.selectTone(tone) })
                    }
                }
                .padding(.horizontal, 10)
            }

            if case .replies = model.state {
                KBColors.borderDim.frame(width: 0.5, height: 16).padding(.horizontal, 2)
                Button { model.regenerate() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(height: 36)
        .background(
            KBColors.deep
                .overlay(alignment: .top) {
                    KBColors.borderHair.frame(height: 1)
                }
        )
        .animation(.easeInOut(duration: 0.18), value: stateTag)
    }

    private var stateTag: Int {
        switch model.state {
        case .idle:         return 0
        case .loading:      return 1
        case .replies:      return 2
        case .error:        return 3
        case .editReply:    return 4
        case .collapsed:    return 5
        case .editContact:  return 6
        case .disambiguate: return 7
        case .editIntent:   return 8
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

// MARK: - Keyboard Input Area

enum KBInputMode { case context, edit }

struct KBInputArea: View {
    @ObservedObject var model: KeyboardModel
    let mode: KBInputMode
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)

            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? placeholder : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty ? Color(UIColor.placeholderText) : Color(UIColor.label))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(mode == .context ? "Cancel" : "Back") { model.cancelInput() }
                    .font(.system(size: 13))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            ReplrKeyboard(
                isShifted: model.isShifted,
                kbMode: model.kbMode,
                doneLabel: mode == .context ? "Save" : "Send",
                onChar: { model.type($0) },
                onSpace: { model.space() },
                onBackspace: { model.backspace() },
                onShift: { model.toggleShift() },
                onMode: { model.toggleMode() },
                onDone: { model.confirmInput() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KBColors.from(cs).bg)
        }
    }

    private var placeholder: String { mode == .context ? "Type context…" : "Edit reply…" }
}

// MARK: - Edit Contact View

struct EditContactView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? "Contact name" : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty
                                     ? Color(UIColor.placeholderText)
                                     : Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        KBColors.accent.opacity(0.5).frame(height: 1)
                    }

                Button("Done") { model.confirmInput() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KBColors.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            Button {
                model.onDifferentPerson?(model.inputText)
            } label: {
                Text("Different person")
                    .font(.system(size: 13))
                    .foregroundColor(KBColors.textDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .opacity(model.inputText.isEmpty ? 0.4 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(model.inputText.isEmpty)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            ReplrKeyboard(
                isShifted: model.isShifted,
                kbMode: model.kbMode,
                doneLabel: "Done",
                onChar: { model.type($0) },
                onSpace: { model.space() },
                onBackspace: { model.backspace() },
                onShift: { model.toggleShift() },
                onMode: { model.toggleMode() },
                onDone: { model.confirmInput() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KBColors.from(cs).bg)
        }
    }
}

// MARK: - Edit Intent View

struct EditIntentView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? "What do you want to say…" : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty
                                     ? Color(UIColor.placeholderText)
                                     : Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        KBColors.accent.opacity(0.5).frame(height: 1)
                    }

                Button("Set") { model.confirmInput() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KBColors.accent)
                    .buttonStyle(.plain)

                Button("Cancel") { model.cancelInput() }
                    .font(.system(size: 13))
                    .foregroundColor(KBColors.textDim)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) { Color(UIColor.separator).frame(height: 0.5) }

            ReplrKeyboard(
                isShifted: model.isShifted,
                kbMode: model.kbMode,
                doneLabel: "Set",
                onChar: { model.type($0) },
                onSpace: { model.space() },
                onBackspace: { model.backspace() },
                onShift: { model.toggleShift() },
                onMode: { model.toggleMode() },
                onDone: { model.confirmInput() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KBColors.from(cs).bg)
        }
    }
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

// MARK: - QWERTY Keyboard

struct ReplrKeyboard: View {
    let isShifted: Bool
    let kbMode: KBMode
    let doneLabel: String
    let doneIsAccent: Bool = true // NEW — true: mustard Send, false: taupe return
    let onChar: (String) -> Void
    let onSpace: () -> Void
    let onBackspace: () -> Void
    let onShift: () -> Void
    let onMode: () -> Void
    let onDone: () -> Void

    @Environment(\.colorScheme) private var cs

    private static let alpha1 = ["q","w","e","r","t","y","u","i","o","p"]
    private static let alpha2 = ["a","s","d","f","g","h","j","k","l"]
    private static let alpha3 = ["z","x","c","v","b","n","m"]
    private static let num1   = ["1","2","3","4","5","6","7","8","9","0"]
    private static let num2   = ["-","/",":",";","(",")","$","&","@","\""]
    private static let num3   = [".",",","?","!","'","+","="]

    var body: some View {
        let c = KBColors.from(cs)
        GeometryReader { geo in
            // hPad is the horizontal padding applied to the VStack.
            // Key widths are computed from geo.size.width minus 2*hPad so rows
            // exactly fill the available space without overflowing.
            let hPad: CGFloat = 3
            let gap: CGFloat  = 5
            // kH fills available height: 4 rows, 3 gaps, 2×7pt vertical padding
            let kH  = max(36, floor((geo.size.height - 14 - 3 * gap) / 4))
            let w   = geo.size.width - 2 * hPad
            let kW  = floor((w - 9 * gap) / 10)
            // row 3 has 9 items → 8 HStack gaps; fnW sized so row exactly fills w
            let fnW = floor((w - 8 * gap - 7 * kW) / 2)

            VStack(spacing: gap) {
                if kbMode == .alpha {
                    alphaLayout(kW: kW, fnW: fnW, kH: kH, gap: gap, c: c)
                } else {
                    numericLayout(kW: kW, fnW: fnW, kH: kH, gap: gap, c: c)
                }

                // Row 4: mode + space + done
                HStack(spacing: gap) {
                    ModeKey(label: kbMode == .alpha ? "123" : "ABC",
                            width: fnW * 1.15, height: kH, c: c, action: onMode)
                    SpaceKey(height: kH, c: c, action: onSpace)
                    DoneKey(label: doneLabel, width: fnW * 1.45, height: kH,
                            isAccent: doneIsAccent, c: c, action: onDone)
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, 7)
        }
    }

    @ViewBuilder
    private func alphaLayout(kW: CGFloat, fnW: CGFloat, kH: CGFloat, gap: CGFloat, c: KBColors) -> some View {
        // Row 1
        HStack(spacing: gap) {
            ForEach(Self.alpha1, id: \.self) { ch in
                CharKey(char: ch, shifted: isShifted, width: kW, height: kH, c: c) { onChar(ch) }
            }
        }
        // Row 2 — centered
        HStack(spacing: gap) {
            Spacer()
            ForEach(Self.alpha2, id: \.self) { ch in
                CharKey(char: ch, shifted: isShifted, width: kW, height: kH, c: c) { onChar(ch) }
            }
            Spacer()
        }
        // Row 3 — shift + letters + delete
        HStack(spacing: gap) {
            ShiftKey(isShifted: isShifted, width: fnW, height: kH, c: c, action: onShift)
            ForEach(Self.alpha3, id: \.self) { ch in
                CharKey(char: ch, shifted: isShifted, width: kW, height: kH, c: c) { onChar(ch) }
            }
            DeleteKey(width: fnW, height: kH, c: c, action: onBackspace)
        }
    }

    @ViewBuilder
    private func numericLayout(kW: CGFloat, fnW: CGFloat, kH: CGFloat, gap: CGFloat, c: KBColors) -> some View {
        // Row 1: digits
        HStack(spacing: gap) {
            ForEach(Self.num1, id: \.self) { ch in
                CharKey(char: ch, shifted: false, width: kW, height: kH, c: c) { onChar(ch) }
            }
        }
        // Row 2: symbols (10 keys, same widths)
        HStack(spacing: gap) {
            ForEach(Self.num2, id: \.self) { ch in
                CharKey(char: ch, shifted: false, width: kW, height: kH, c: c) { onChar(ch) }
            }
        }
        // Row 3: 7 symbols + delete (same structure as alpha row 3)
        HStack(spacing: gap) {
            // placeholder same width as shift key
            Color.clear.frame(width: fnW, height: kH)
            ForEach(Self.num3, id: \.self) { ch in
                CharKey(char: ch, shifted: false, width: kW, height: kH, c: c) { onChar(ch) }
            }
            DeleteKey(width: fnW, height: kH, c: c, action: onBackspace)
        }
    }
}

// MARK: - Key Components

private struct CharKey: View {
    let char: String
    let shifted: Bool
    let width: CGFloat
    let height: CGFloat
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text(shifted ? char.uppercased() : char)
            .font(.system(size: 17))
            .foregroundColor(c.letterText)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(c.alpha)
                    .opacity(pressed ? 0.6 : 1.0)
                    .shadow(color: c.shadow, radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onEnded { _ in action() }
            )
    }
}

private struct ShiftKey: View {
    let isShifted: Bool
    let width: CGFloat
    let height: CGFloat
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Image(systemName: isShifted ? "shift.fill" : "shift")
            .font(.system(size: 15, weight: .light))
            .foregroundColor(isShifted ? Color.accentColor : c.fnText)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isShifted ? c.alpha : c.fn)
                    .opacity(pressed ? 0.7 : 1.0)
                    .shadow(color: c.shadow, radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onEnded { _ in action() }
            )
    }
}

// Hold-to-repeat delete
private class RepeatTimer: ObservableObject {
    var timer: Timer?
    func start(delay: TimeInterval = 0.4, interval: TimeInterval = 0.075, action: @escaping () -> Void) {
        stop()
        action()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in action() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
}

private struct DeleteKey: View {
    let width: CGFloat
    let height: CGFloat
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false
    @StateObject private var repeater = RepeatTimer()

    var body: some View {
        Image(systemName: "delete.backward")
            .font(.system(size: 15, weight: .light))
            .foregroundColor(c.fnText)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(c.fn)
                    .opacity(pressed ? 0.7 : 1.0)
                    .shadow(color: c.shadow, radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onChanged { _ in
                        if repeater.timer == nil { repeater.start(action: action) }
                    }
                    .onEnded { _ in repeater.stop() }
            )
    }
}

private struct SpaceKey: View {
    let height: CGFloat
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text("space")
            .font(.system(size: 14))
            .foregroundColor(c.subtext)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(c.alpha)
                    .opacity(pressed ? 0.6 : 1.0)
                    .shadow(color: c.shadow, radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onEnded { _ in action() }
            )
    }
}

private struct ModeKey: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(c.fnText)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(c.fn)
                    .opacity(pressed ? 0.7 : 1.0)
                    .shadow(color: c.shadow, radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onEnded { _ in action() }
            )
    }
}

private struct DoneKey: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let isAccent: Bool   // true = mustard Send, false = taupe return
    let c: KBColors
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isAccent ? KBColors.accentFg : c.fnText)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isAccent ? KBColors.accent : c.fn)
                    .opacity(pressed ? 0.75 : 1.0)
                    .shadow(color: isAccent ? KBColors.accentShadow.opacity(0.6) : c.shadow,
                            radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, s, _ in s = true }
                    .onEnded { _ in action() }
            )
    }
}

// MARK: - Reply Carousel

struct ReplyCarousel: View {
    let replies: [String]
    let onSelect: (String) -> Void
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                    ReplyCard(text: reply, onTap: { onSelect(reply) })
                        .padding(.horizontal, 4)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if replies.count > 1 {
                PageDots(count: replies.count, current: currentPage)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct PageDots: View {
    let count: Int; let current: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? KBColors.accent : KBColors.textDim)
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

struct ReplyCard: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(KBColors.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
                    .padding(.top, 13)

                Divider().opacity(0.15)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up").font(.system(size: 10))
                    Text("Send").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(KBColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .buttonStyle(ReplyCardButtonStyle())
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ReplyCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Step Row (B2 idle design)

struct StepRow<Trailing: View>: View {
    let number: String
    let isActive: Bool
    let label: String
    let trailing: Trailing

    init(number: String, isActive: Bool, label: String, @ViewBuilder trailing: () -> Trailing) {
        self.number = number
        self.isActive = isActive
        self.label = label
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(isActive ? KBColors.accent : KBColors.textDim)
                .frame(minWidth: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(isActive ? KBColors.accent : KBColors.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(isActive ? KBColors.surfaceActive : KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isActive ? KBColors.accent : KBColors.borderDim)
                .frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Collapsed Bar (full conversation visible for screenshot)

struct CollapsedBar: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { model.state = .idle }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KBColors.accent)
                Text("Screenshot now · triple-tap to generate")
                    .font(.system(size: 12))
                    .foregroundColor(KBColors.accent)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(KBColors.deep)
    }
}

// MARK: - Idle + Always-On Keyboard

struct ReplrStrip: View {
    @ObservedObject var model: KeyboardModel

    private var isCaptureIdleState: Bool {
        guard model.inputMode == .chat else { return false }  // email mode never shows capture CTA
        guard model.lastInsertedReply == nil else { return false }
        if case .idle = model.state { return model.hasAnySessions }
        return false
    }

    private var canSwitchMode: Bool {
        switch model.state {
        case .idle, .loading, .error, .replies: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode row: Chat / Email tabs + collapse chevron
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        model.inputMode = .chat
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.system(size: 10, weight: .medium))
                        Text("Chat")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(model.inputMode == .chat ? KBColors.accentFg : KBColors.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(model.inputMode == .chat ? KBColors.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSwitchMode)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        if model.selectedTone.name == "Dating" {
                            model.selectedTone = model.tones.first { $0.name != "Dating" } ?? model.selectedTone
                        }
                        model.inputMode = .email
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                            .font(.system(size: 10, weight: .medium))
                        Text("Email")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(model.inputMode == .email ? KBColors.accentFg : KBColors.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(model.inputMode == .email ? KBColors.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSwitchMode)

                Spacer()

                Button { model.collapse() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
            .frame(height: 28)

            KBColors.borderHair.frame(height: 0.5)

            // Action bar: capture CTA / loading / error / undo
            Group {
                if isCaptureIdleState {
                    Button { model.collapse() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 11, weight: .medium))
                            Text("Capture replies")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(KBColors.accentFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(KBColors.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        stripCentreContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                        intentChip
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: model.hasAnySessions)
            .animation(.easeInOut(duration: 0.15), value: model.lastInsertedReply == nil)

            KBColors.borderHair.frame(height: 0.5)

            // Tone row: pills + optional globe
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(model.tones.filter { model.inputMode == .chat || $0.name != "Dating" }) { tone in
                            TonePill(name: tone.name,
                                     isSelected: tone.name == model.selectedTone.name,
                                     action: { model.selectTone(tone) })
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
        .background(
            KBColors.deep
                .overlay(alignment: .bottom) { KBColors.borderHair.frame(height: 1) }
        )
    }

    // MARK: - Smart centre content

    @ViewBuilder
    private var stripCentreContent: some View {
        // Undo chip takes priority over all other states
        if model.lastInsertedReply != nil {
            Button { model.onUndoInsert?() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .medium))
                    Text("Undo")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(KBColors.accentFg)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(KBColors.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        } else {
            switch model.state {
            case .idle where !model.hasAnySessions:
                // No sessions yet — static hint label
                Text("Set up triple-tap →")
                    .font(.system(size: 12))
                    .foregroundColor(KBColors.textDim)

            case .loading:
                HStack(spacing: 5) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.65)
                        .tint(KBColors.textDim)
                    Text("Generating…")
                        .font(.system(size: 12))
                        .foregroundColor(KBColors.textDim)
                }

            case .error:
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 9, weight: .medium))
                        Text("Failed")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(KBColors.textDim)

                    Button { model.retryGeneration() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .medium))
                            Text("Retry")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(KBColors.accentFg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(KBColors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

            case .replies:
                Button { model.regenerate() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text("Regenerate")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(KBColors.textDim)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))

            default:
                // .editReply, .editContact, .disambiguate, .collapsed — empty
                Spacer()
            }
        }
    }

    // MARK: - Intent chip (right side of action bar)

    @ViewBuilder
    private var intentChip: some View {
        if let hint = model.intentHint {
            // Filled — tap to clear
            Button { model.clearIntent() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text(hint)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(KBColors.accentFg)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(KBColors.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        } else {
            // Empty — tap to capture whatever is in the text field
            Button { model.captureIntent() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.square")
                        .font(.system(size: 9, weight: .medium))
                    Text("intent")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(KBColors.textDim)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    Capsule()
                        .stroke(KBColors.textDim.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                )
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
    }
}

struct IdleWithKeyboard: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            if model.inputMode == .email {
                emailIdleBody
            } else {
                ReplrKeyboard(
                    isShifted: model.isShifted,
                    kbMode: model.kbMode,
                    doneLabel: "return",
                    onChar: { model.type($0) },
                    onSpace: { model.space() },
                    onBackspace: { model.backspace() },
                    onShift: { model.toggleShift() },
                    onMode: { model.toggleMode() },
                    onDone: { model.confirmInput() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KBColors.from(cs).bg)
            }
        }
    }

    private var emailIdleBody: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 28))
                .foregroundColor(KBColors.textDim)
            Button {
                model.generateEmailReply()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                    Text("Paste & Generate")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            Text("Reads email from clipboard")
                .font(.caption)
                .foregroundColor(KBColors.textDim)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.from(cs).bg)
    }
}

// MARK: - Static State Views

struct IdleStateView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 5) {
            StepRow(number: "1", isActive: true, label: "Context") {
                if model.pendingContext.isEmpty {
                    Text("Start typing in chat…")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.accentSubtle)
                } else {
                    Text(model.pendingContext)
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.accent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            }

            StepRow(number: "2", isActive: true, label: "Pick a tone below") {
                EmptyView()
            }

            HStack {
                Spacer()
                Text("Triple-tap to generate →")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KBColors.accent)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// Compact 50px strip shown while the intent is generating — keeps conversation visible
struct GeneratingView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(KBColors.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: phase)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                for i in 0..<3 {
                    phase = i
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if Task.isCancelled { return }
                }
            }
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

struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
