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
}

enum KBMode { case alpha, numeric }

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

    init(initialTone: Tone) {
        self.selectedTone = initialTone
        self.tones = AppGroupService.shared.readTones()
    }

    // MARK: - Input

    func type(_ char: String) {
        let out = isShifted ? char.uppercased() : char
        switch state {
        case .editReply, .editContact: inputText += out
        default: onTypeChar?(out)
        }
        if isShifted, kbMode == .alpha { isShifted = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func backspace() {
        switch state {
        case .editReply, .editContact:
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
        default:
            onDeleteChar?()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func space() {
        switch state {
        case .editReply, .editContact: inputText += " "
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
        default:
            onReturnChar?()
        }
    }

    func cancelInput() {
        withAnimation(.easeInOut(duration: 0.18)) {
            switch state {
            case .editReply, .editContact:
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
        withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
    }
}

// MARK: - Root View

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    private var showToneBar: Bool {
        switch model.state {
        case .replies, .error: return true
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
                GeneratingView().transition(.opacity)
            case .replies(let replies):
                VStack(spacing: 0) {
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
                            .foregroundColor(KBColors.amberText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        KBColors.borderHair.frame(height: 0.5)
                    }
                    ReplyCarousel(replies: replies,
                                  onSelect: { model.selectReply($0) },
                                  onEdit: { model.enterEditReply($0) })
                }
                .transition(.opacity)
            case .editReply:
                KBInputArea(model: model, mode: .edit).transition(.opacity)
            case .error(let msg):
                ErrorStateView(message: msg).transition(.opacity)
            case .editContact:
                EditContactView(model: model).transition(.opacity)
            case .disambiguate(let name, let candidates):
                DisambiguateView(
                    name: name,
                    candidates: candidates,
                    onSelectContact: { model.onSelectContact?($0) },
                    onCreateNew: { model.onCreateNewContact?($0) }
                )
                .transition(.opacity)
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
                .background(isSelected ? KBColors.amber : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Keyboard Colors

struct KBColors {
    let alpha: Color      // letter key background
    let fn: Color         // special key (shift, delete, 123, space)
    let text: Color       // key label
    let subtext: Color    // "space" label
    let shadow: Color
    let bg: Color         // area between keys

    static func from(_ cs: ColorScheme) -> KBColors {
        cs == .dark
        ? KBColors(
            alpha:   Color(white: 0.30),
            fn:      Color(white: 0.20),
            text:    .white,
            subtext: Color(white: 0.55),
            shadow:  .clear,
            bg:      Color(red: 0.067, green: 0.067, blue: 0.067) // matches KBColors.background
          )
        : KBColors(
            alpha:   .white,
            fn:      Color(red: 0.68, green: 0.70, blue: 0.73),
            text:    .black,
            subtext: Color(UIColor.secondaryLabel),
            shadow:  Color.black.opacity(0.28),
            bg:      Color(red: 0.82, green: 0.83, blue: 0.85)
          )
    }

    // Design system tokens — used by state views, not key components
    static let background    = Color(red: 0.067, green: 0.067, blue: 0.067) // #111111
    static let deep          = Color(red: 0.051, green: 0.051, blue: 0.051) // #0D0D0D
    static let surface       = Color(red: 0.086, green: 0.086, blue: 0.086) // #161616
    static let surfaceActive = Color(red: 0.102, green: 0.086, blue: 0.000) // #1A1600
    static let borderHair    = Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E
    static let borderDim     = Color(red: 0.165, green: 0.165, blue: 0.165) // #2A2A2A
    static let amber         = Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623
    static let amberText     = Color(red: 0.784, green: 0.627, blue: 0.376) // #C8A060
    static let amberSubtle   = Color(red: 0.353, green: 0.282, blue: 0.125) // #5A4820
    static let amberBg       = Color(red: 0.165, green: 0.125, blue: 0.000) // #2A2000
    static let amberBgBorder = Color(red: 0.227, green: 0.188, blue: 0.063) // #3A3010
    static let textPrimary   = Color(red: 0.878, green: 0.878, blue: 0.878) // #E0E0E0
    static let textDim       = Color(red: 0.333, green: 0.333, blue: 0.333) // #555555
    static let textGhost     = borderDim
}

// MARK: - Keyboard Input Area

enum KBInputMode { case context, edit }

struct KBInputArea: View {
    @ObservedObject var model: KeyboardModel
    let mode: KBInputMode
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            // Text display
            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? placeholder : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty ? Color(UIColor.placeholderText) : Color(UIColor.label))
                    .lineLimit(mode == .edit ? 2 : 1)
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
            .background(KBColors.from(cs).bg)  // fill gaps between keys
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
            HStack(spacing: 8) {
                Text(model.inputText.isEmpty ? "Contact name" : model.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(model.inputText.isEmpty
                                     ? Color(UIColor.placeholderText)
                                     : Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        KBColors.amber.opacity(0.5).frame(height: 1)
                    }

                Button("Done") { model.confirmInput() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KBColors.amber)
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
                        .foregroundColor(KBColors.amber)
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
                    DoneKey(label: doneLabel, width: fnW * 1.45, height: kH, action: onDone)
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
            .foregroundColor(c.text)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
            .foregroundColor(isShifted ? Color.accentColor : c.text)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
            .foregroundColor(c.text)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
            .foregroundColor(c.text)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
    let action: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(KBColors.background)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(KBColors.amber)
                    .opacity(pressed ? 0.75 : 1.0)
                    .shadow(color: KBColors.amber.opacity(0.3), radius: 0, y: 1)
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
    let onEdit: (String) -> Void
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if replies.count > 1 {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KBColors.surface)
                        .opacity(0.6)
                        .padding(.leading, 10)
                        .padding(.trailing, 8)
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                        ReplyCard(
                            text: reply,
                            onTap: { onSelect(reply) },
                            onEdit: { onEdit(reply) }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.trailing, 8)
                .padding(.bottom, 6)
            }
            .frame(height: 130)

            if replies.count > 1 {
                PageDots(count: replies.count, current: currentPage)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct PageDots: View {
    let count: Int; let current: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? KBColors.amber : KBColors.textDim)
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

struct ReplyCard: View {
    let text: String
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: onTap) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(KBColors.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
                    .padding(.top, 13)
                    .padding(.bottom, 32)
            }
            .buttonStyle(ReplyCardButtonStyle())

            HStack(spacing: 0) {
                Spacer()
                Button(action: onEdit) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil").font(.system(size: 10))
                        Text("Edit").font(.system(size: 11))
                    }
                    .foregroundColor(KBColors.amber)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 9)
        }
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
                .foregroundColor(isActive ? KBColors.amber : KBColors.textDim)
                .frame(minWidth: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(isActive ? KBColors.amberText : KBColors.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(isActive ? KBColors.surfaceActive : KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isActive ? KBColors.amber : KBColors.borderDim)
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
                    .foregroundColor(KBColors.amber)
                Text("Screenshot now · triple-tap to generate")
                    .font(.system(size: 12))
                    .foregroundColor(KBColors.amberText)
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

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: entire row taps to collapse; "Use as context" captures its own sub-tap
            HStack(spacing: 0) {
                Text(model.pendingContext.isEmpty ? "Screenshot → triple-tap" : model.pendingContext)
                    .font(.system(size: 12))
                    .foregroundColor(model.pendingContext.isEmpty ? KBColors.amber.opacity(0.7) : KBColors.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !model.pendingContext.isEmpty {
                    Button { model.useAsContext() } label: {
                        Text("Use as context")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KBColors.amber)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(KBColors.amberBg)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                // Visual affordance only — row tap handles collapse
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KBColors.textDim)
                    .frame(width: 36, height: 28)
            }
            .padding(.leading, 12)
            .frame(height: 28)
            .contentShape(Rectangle())
            .onTapGesture { model.collapse() }
            .animation(.easeInOut(duration: 0.15), value: model.pendingContext.isEmpty)

            KBColors.borderHair.frame(height: 0.5)

            // Row 2: tone pills + optional globe key
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(model.tones) { tone in
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
}

struct IdleWithKeyboard: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
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

// MARK: - Static State Views

struct IdleStateView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 5) {
            StepRow(number: "1", isActive: true, label: "Context") {
                if model.pendingContext.isEmpty {
                    Text("Start typing in chat…")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.amberSubtle)
                } else {
                    Text(model.pendingContext)
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.amberText)
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
                    .foregroundColor(KBColors.amber)
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
                    .fill(KBColors.amber)
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
