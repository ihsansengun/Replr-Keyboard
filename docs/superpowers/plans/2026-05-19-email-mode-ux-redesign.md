# Email Mode UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `ReplrStrip` to a 2-row layout (mode row + tone row = 60px), introduce icon-only mode tabs with an explicit intent capture button, add a stretch CTA that triggers email generation or chat collapse, and update the warm dark keyboard palette.

**Architecture:** All UI changes live in `ReplrKeyboard/Views/KeyboardView.swift` (the single SwiftUI file for the keyboard). `KeyboardViewController.swift` gets a new callback wire-up and a chrome-height fix. No backend changes — `ReplyService.generateRepliesFromEmail` and `resolveContact` (`Shared/ContactResolver.swift`) already exist.

**Tech Stack:** SwiftUI, UIKit (`UIInputViewController`, `UITextDocumentProxy`), Combine, App Group via `AppGroupService`

---

## File Map

| File | Change |
|---|---|
| `ReplrKeyboard/Views/KeyboardView.swift` | All palette, strip, intent, QWERTY, reply card changes |
| `ReplrKeyboard/KeyboardViewController.swift` | Wire `onDeleteTextProxy`, fix chrome height |

---

### Task 1: Warm dark palette

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `KBColors` struct (lines 397–465)

- [ ] **Step 1: Update `KBColors` instance struct** — split `text` into `letterText` + `fnText`, update `from(cs)` to always return warm dark values

Replace the entire `struct KBColors` and its instance `from(_:)` method (keep static tokens — those come next):

```swift
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
```

- [ ] **Step 2: Update static design tokens** — replace adaptive UIColor-based values with fixed warm dark values

Replace the static section inside `struct KBColors` (starting with `// Mustard yellow`, lines 428–465):

```swift
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
```

- [ ] **Step 3: Update key components to use split text colors**

In `CharKey.body` (line ~864), change `c.text` → `c.letterText`:
```swift
Text(shifted ? char.uppercased() : char)
    .font(.system(size: 17))
    .foregroundColor(c.letterText)  // was c.text
```

In `ShiftKey.body` (line ~895), change `c.text` → `c.fnText`:
```swift
.foregroundColor(isShifted ? Color.accentColor : c.fnText)  // was c.text
```
And in its background, the non-shifted fill uses `c.fn`:
```swift
.fill(isShifted ? c.alpha : c.fn)  // unchanged — already correct
```

In `DeleteKey.body` (line ~940), change `c.text` → `c.fnText`:
```swift
Image(systemName: "delete.backward")
    .font(.system(size: 15, weight: .light))
    .foregroundColor(c.fnText)  // was c.text
```

In `ModeKey.body` (line ~990), change `c.text` → `c.fnText`:
```swift
Text(label)
    .font(.system(size: 13, weight: .regular))
    .foregroundColor(c.fnText)  // was c.text
```

- [ ] **Step 4: Update `DoneKey` to support fn-style (email return key)**

Replace `DoneKey` struct entirely:
```swift
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
```

- [ ] **Step 5: Update `ReplrKeyboard` to pass `isAccent` and `c` through to `DoneKey`**

Add `doneIsAccent: Bool = true` parameter to `ReplrKeyboard`:
```swift
struct ReplrKeyboard: View {
    let isShifted: Bool
    let kbMode: KBMode
    let doneLabel: String
    let doneIsAccent: Bool        // NEW — true: mustard Send, false: taupe return
    let onChar: (String) -> Void
    let onSpace: () -> Void
    let onBackspace: () -> Void
    let onShift: () -> Void
    let onMode: () -> Void
    let onDone: () -> Void

    @Environment(\.colorScheme) private var cs
    // ... existing key layout arrays ...
```

In row 4 of `ReplrKeyboard.body`, pass `isAccent` and `c` to `DoneKey`:
```swift
// Row 4: mode + space + done
HStack(spacing: gap) {
    ModeKey(label: kbMode == .alpha ? "123" : "ABC",
            width: fnW * 1.15, height: kH, c: c, action: onMode)
    SpaceKey(height: kH, c: c, action: onSpace)
    DoneKey(label: doneLabel, width: fnW * 1.45, height: kH,
            isAccent: doneIsAccent, c: c, action: onDone)  // CHANGED
}
```

- [ ] **Step 6: Build in Xcode — confirm no compile errors before continuing**

Run: `⌘B` in Xcode scheme `ReplrKeyboard`
Expected: zero errors. Fix any `c.text` references still remaining.

- [ ] **Step 7: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: warm dark palette — cream keys, taupe fn keys, amber bg"
```

---

### Task 2: Remove `editIntent` state

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Remove `editIntent` from `KeyboardState` enum** (line 7–17)

```swift
enum KeyboardState: Equatable {
    case idle
    case collapsed
    case loading
    case replies([String])
    case editReply(String)
    case error(String)
    case editContact(String)
    case disambiguate(name: String, candidates: [Contact])
    // editIntent removed
}
```

- [ ] **Step 2: Remove `editIntent` from `type()`, `backspace()`, `space()`** (lines 65–93)

In `type()`:
```swift
func type(_ char: String) {
    let out = isShifted ? char.uppercased() : char
    switch state {
    case .editReply, .editContact: inputText += out   // removed editIntent
    default: onTypeChar?(out)
    }
    if isShifted, kbMode == .alpha { isShifted = false }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

In `backspace()`:
```swift
func backspace() {
    switch state {
    case .editReply, .editContact:   // removed editIntent
        guard !inputText.isEmpty else { return }
        inputText.removeLast()
    default:
        onDeleteChar?()
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

In `space()`:
```swift
func space() {
    switch state {
    case .editReply, .editContact: inputText += " "   // removed editIntent
    default: onSpaceChar?()
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

- [ ] **Step 3: Remove `editIntent` branch from `confirmInput()` and `cancelInput()`** (lines 98–129)

In `confirmInput()`, delete the `case .editIntent:` branch entirely. The `default:` case handles pressing the return/done key in normal states.

In `cancelInput()`:
```swift
func cancelInput() {
    withAnimation(.easeInOut(duration: 0.18)) {
        switch state {
        case .editReply, .editContact:   // removed editIntent
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
```

- [ ] **Step 4: Remove `editIntent` from `contentArea` switch** (lines 307–309)

Delete these lines from `KeyboardRootView.contentArea`:
```swift
// DELETE:
case .editIntent:
    IdleWithKeyboard(model: model).transition(.opacity)
```

- [ ] **Step 5: Update `stateTag` computed property** — remove case 8

```swift
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
    // editIntent case removed
    }
}
```

- [ ] **Step 6: Delete `EditIntentView` struct entirely** (lines 580–628)

Remove the entire `// MARK: - Edit Intent View` block including `struct EditIntentView`.

- [ ] **Step 7: Build — confirm zero errors**

Run: `⌘B`. Fix any remaining `editIntent` references.

- [ ] **Step 8: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: remove editIntent state — intent capture now reads text proxy directly"
```

---

### Task 3: `captureIntent()` + text proxy deletion

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `KeyboardModel`
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Add `onDeleteTextProxy` callback to `KeyboardModel`** (after line 56, near other callbacks)

```swift
var onDeleteTextProxy: (() -> Void)?   // deletes draft from text proxy after intent capture
```

- [ ] **Step 2: Update `captureIntent()` to delete the text proxy after saving**

Replace the existing `captureIntent()` method (lines 141–148):
```swift
func captureIntent() {
    guard let raw = readTextProxy?(),
          !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    intentHint = trimmed
    AppGroupService.shared.saveIntentHint(trimmed)
    pendingContext = ""
    onDeleteTextProxy?()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
```

- [ ] **Step 3: Wire `onDeleteTextProxy` in `KeyboardViewController.viewDidLoad()`**

Add after the existing `model.readTextProxy = ...` line (line 85):
```swift
model.onDeleteTextProxy = { [weak self] in
    guard let self else { return }
    let draft = self.textDocumentProxy.documentContextBeforeInput ?? ""
    for _ in draft.unicodeScalars { self.textDocumentProxy.deleteBackward() }
}
```

- [ ] **Step 4: Build — confirm zero errors**

Run: `⌘B`.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: captureIntent clears text proxy after saving — no orphan draft"
```

---

### Task 4: `ReplrStrip` redesign — icon tabs + stretch CTA

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `ReplrStrip` struct (lines 1189–1462)

The new strip is **60px** (mode row 28px + tone row 32px). The entire action bar row is removed. The mode row gets 3 icon-only tabs (bubble.left / envelope / bookmark) + a stretch CTA that shows undo, loading, error, or mode-specific label.

- [ ] **Step 1: Replace the entire `ReplrStrip` struct**

Delete lines 1189–1462 and replace with:

```swift
// MARK: - Replr Strip (mode row + tone row = 60px)

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

    // Taupe — matches keyFn color, used for chat CTA
    private let taupe = Color(red: 0.420, green: 0.376, blue: 0.314)

    var body: some View {
        VStack(spacing: 0) {
            // ── Mode row ──────────────────────────────────────────────────
            HStack(spacing: 3) {
                // Chat tab
                modeTab(symbol: "bubble.left", isActive: model.inputMode == .chat) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        model.inputMode = .chat
                    }
                }
                .disabled(!canSwitchMode)

                // Email tab
                modeTab(symbol: "envelope", isActive: model.inputMode == .email) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if case .replies = model.state { model.regenerate() }
                        if model.selectedTone.name == "Dating" {
                            model.selectedTone = model.tones.first { $0.name != "Dating" } ?? model.selectedTone
                        }
                        model.inputMode = .email
                    }
                }
                .disabled(!canSwitchMode)

                // Intent tab
                intentTab

                // Stretch CTA
                ctaButton
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(height: 28)

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
    private func modeTab(symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundColor(isActive ? KBColors.accentFg : KBColors.accent)
                .frame(width: 28, height: 20)
                .background(isActive ? KBColors.accent : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isActive ? Color.clear : KBColors.accent.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(isActive ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Intent Tab

    @ViewBuilder
    private var intentTab: some View {
        Button {
            switch intentTabState {
            case .empty:    break
            case .ready:    model.captureIntent()
            case .captured: model.clearIntent()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bookmark")
                    .font(.system(size: 14, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(intentTabState == .captured ? KBColors.accentFg : KBColors.accent)
                    .frame(width: 28, height: 20)
                    .background(intentTabBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(intentTabBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .opacity(intentTabState == .empty ? 0.18 : 1.0)

                if intentTabState == .captured {
                    Circle()
                        .fill(KBColors.accentFg)
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: intentTabState)
    }

    private var intentTabBg: Color {
        switch intentTabState {
        case .empty:    return Color.clear
        case .ready:    return KBColors.accent.opacity(0.15)
        case .captured: return KBColors.accent
        }
    }

    private var intentTabBorder: Color {
        intentTabState == .ready ? KBColors.accent.opacity(0.8) : Color.clear
    }

    // MARK: - CTA Button (fills remaining width)

    @ViewBuilder
    private var ctaButton: some View {
        Group {
            if model.lastInsertedReply != nil {
                // Undo chip — highest priority
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
                    // Label visible but near-invisible — indicates mode, not actionable
                    Text(model.inputMode == .email ? "↑ Generate from clipboard" : "↑ Capture replies")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(model.inputMode == .email
                                         ? KBColors.accent.opacity(0.15)
                                         : taupe.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)

                case .idle where !model.hasAnySessions && model.inputMode == .chat:
                    // New user — no sessions yet
                    Text("Set up triple-tap →")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 20)
                        .padding(.leading, 4)

                default:
                    // Normal idle (and any other state)
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
                        Button { model.collapse() } label: {
                            Text("↑ Capture replies")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(taupe)
                                .frame(maxWidth: .infinity)
                                .frame(height: 20)
                                .background(taupe.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(taupe.opacity(0.5), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.lastInsertedReply == nil)
        .animation(.easeInOut(duration: 0.15), value: stateTag)
    }

    private var stateTag: Int {
        switch model.state {
        case .idle:    return 0
        case .loading: return 1
        case .error:   return 2
        case .replies: return 3
        default:       return 4
        }
    }
}
```

- [ ] **Step 2: Build — confirm zero errors and no references to removed properties**

Run: `⌘B`. In particular confirm `isCaptureIdleState`, `stripCentreContent`, `intentChip`, `canSwitchMode` (old one) are all removed without dangling references.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: ReplrStrip redesign — icon tabs + stretch CTA, strip shrinks to 60px"
```

---

### Task 5: Email mode QWERTY keyboard

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `IdleWithKeyboard` (lines 1464–1522)

- [ ] **Step 1: Replace `IdleWithKeyboard`**

Delete lines 1464–1522 and replace with:

```swift
// MARK: - Idle + Always-On Keyboard

struct IdleWithKeyboard: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            ReplrKeyboard(
                isShifted: model.isShifted,
                kbMode: model.kbMode,
                doneLabel: model.inputMode == .email ? "return" : "Send",
                doneIsAccent: model.inputMode == .chat,
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
```

- [ ] **Step 2: Build — confirm zero errors**

Run: `⌘B`. The `emailIdleBody` private var and the `if model.inputMode == .email { emailIdleBody }` branch are gone.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: email mode shows QWERTY with taupe return key instead of Paste&Generate panel"
```

---

### Task 6: `ReplyCard` email footer — Paste + Regenerate

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `ReplyCard`, `ReplyCarousel`, `KeyboardRootView`

- [ ] **Step 1: Replace `ReplyCard` struct** (lines 1077–1119)

Delete the existing `ReplyCard` and replace with:

```swift
struct ReplyCard: View {
    let text: String
    let inputMode: KeyboardInputMode
    let onTap: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
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

            if inputMode == .email {
                emailFooter
            } else {
                chatFooter
            }
        }
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chatFooter: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up").font(.system(size: 10))
                Text("Send").font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(KBColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var emailFooter: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 10))
                    Text("Paste").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(KBColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            KBColors.borderHair.frame(width: 0.5)

            Button(action: onRegenerate) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                    Text("Regenerate").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(KBColors.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        }
    }
}
```

Note: Remove the old `ReplyCardButtonStyle` struct — it's no longer used since `ReplyCard` is no longer a `Button`.

- [ ] **Step 2: Update `ReplyCarousel` to thread `inputMode` and `onRegenerate` through to `ReplyCard`**

Replace `ReplyCarousel` struct (lines 1035–1061):

```swift
struct ReplyCarousel: View {
    let replies: [String]
    let inputMode: KeyboardInputMode
    let onSelect: (String) -> Void
    let onRegenerate: () -> Void
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                    ReplyCard(
                        text: reply,
                        inputMode: inputMode,
                        onTap: { onSelect(reply) },
                        onRegenerate: onRegenerate
                    )
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
```

- [ ] **Step 3: Update the `ReplyCarousel` call site in `KeyboardRootView.contentArea`**

In the `.replies(let replies)` case, update the `ReplyCarousel` call:
```swift
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
        ReplyCarousel(
            replies: replies,
            inputMode: model.inputMode,          // ADDED
            onSelect: { model.selectReply($0) },
            onRegenerate: { model.regenerate() } // ADDED
        )
    }
    .transition(.opacity)
```

- [ ] **Step 4: Build — confirm zero errors**

Run: `⌘B`. Confirm `ReplyCardButtonStyle` (if removed) has no remaining references.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: email reply cards show Paste + Regenerate footer instead of Send"
```

---

### Task 7: Chrome height in `KeyboardViewController`

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift` — `updateHeightFromContent()` (line 273)

- [ ] **Step 1: Fix chrome constant** — strip is now 60px, not 89px

In `updateHeightFromContent()`, change:
```swift
// BEFORE:
let chrome: CGFloat = 89 + (model.contactName != nil ? 28 : 0) + 32
// AFTER:
let chrome: CGFloat = 60 + (model.contactName != nil ? 28 : 0) + 32
```

- [ ] **Step 2: Build — confirm zero errors**

Run: `⌘B`.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "fix: chrome height 89→60 — strip lost one 28px action bar row"
```

---

## Spec Self-Review

### Coverage check

| Spec requirement | Implemented in |
|---|---|
| Warm dark palette — cream keys, taupe fn, charcoal bg | Task 1 |
| `accentFg` #120E00, `accentShadow` #7A5A00 | Task 1 |
| 3 icon tabs (bubble.left / envelope / bookmark) | Task 4 |
| Intent tab: dim / outline / solid+dot states | Task 4 |
| CTA fills remaining width; email = Generate, chat = Capture | Task 4 |
| CTA during loading / error / replies / undo | Task 4 |
| Dating tone hidden in email mode | Already in codebase — preserved in Task 4 |
| Email mode QWERTY: taupe return key | Tasks 1 + 5 |
| Chat mode QWERTY: mustard Send key | Tasks 1 + 5 |
| Remove action bar row (was 28px) | Task 4 |
| `captureIntent()` clears text proxy | Task 3 |
| `editIntent` state removed | Task 2 |
| Email replies: Paste + Regenerate footer | Task 6 |
| Chat replies: Send footer unchanged | Task 6 |
| Chrome height 89→60 | Task 7 |
| `generateEmailReply()` reads clipboard + intent | Already in codebase |
| `ReplyService.generateRepliesFromEmail` | Already in codebase |

### Type / name consistency

- `doneIsAccent: Bool` added to `ReplrKeyboard` — consumed immediately in row 4 via `DoneKey(isAccent: doneIsAccent, ...)` ✓
- `DoneKey` gains `isAccent: Bool` + `c: KBColors` — both provided at the single call site in `ReplrKeyboard.body` ✓
- `IntentTabState` is private to `ReplrStrip` — no external references ✓
- `ReplyCarousel` gains `inputMode` + `onRegenerate` — both supplied by `KeyboardRootView` ✓
- `ReplyCard` gains `inputMode` + `onRegenerate` — both supplied by `ReplyCarousel` ✓
- `onDeleteTextProxy` added to `KeyboardModel` — wired in `KeyboardViewController.viewDidLoad()` ✓

### No placeholders — confirmed: all steps contain complete code ✓
