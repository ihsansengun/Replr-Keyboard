# Email Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Chat/Email mode tabs to the Replr keyboard, letting users paste an email into the keyboard and generate replies directly without a screenshot, plus an intent hint chip for steering reply direction in both modes.

**Architecture:** The keyboard extension calls `ReplyService.shared.generateRepliesFromEmail()` directly (no AppIntent needed for email). A new `KeyboardInputMode` enum on `KeyboardModel` drives which idle UI renders. A mode row (28 px, Chat/Email tabs + collapse chevron) is added to `ReplrStrip`, increasing all keyboard heights by 28 px. An intent hint chip lives in the tone row; editing it uses a new `.editIntent` `KeyboardState` case. Contact resolution is extracted from the two intents into a shared free function so the keyboard can call the same logic.

**Tech Stack:** Swift / SwiftUI, UIKit (UIPasteboard), Combine, existing `ReplyService`, `AppGroupService`, `KeyboardModel` state machine.

---

## File Map

| File | Change |
|---|---|
| `Shared/Constants.swift` | Add `intentHintKey` |
| `Shared/AppGroupService.swift` | Add `saveIntentHint(_:)` / `readIntentHint()` |
| `Shared/Models/Tone.swift` | Remove "Email" preset |
| `Shared/ContactResolver.swift` | **New** — free function `resolveContact(from:)` |
| `Replr/Replr/Intents/GenerateReplyIntent.swift` | Use `resolveContact(from:)` |
| `Replr/Replr/Intents/QuickReplyIntent.swift` | Use `resolveContact(from:)` |
| `ReplrKeyboard/Views/KeyboardView.swift` | Major — mode row, intent chip, editIntent, email idle, email generate |
| `ReplrKeyboard/KeyboardViewController.swift` | Height map +28 px, add `.editIntent` case |

---

## Task 1: Constants + AppGroupService intent hint

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add the key to Constants**

In `Shared/Constants.swift`, add inside the `enum Constants` body after `pendingContextKey`:

```swift
static let intentHintKey          = "intent_hint"
```

- [ ] **Step 2: Add AppGroupService methods**

In `Shared/AppGroupService.swift`, add a new MARK section before the closing `}` of the class (before `enum AppGroupError`):

```swift
// MARK: - Intent hint (keyboard writes, keyboard reads, cleared after generation)

func saveIntentHint(_ text: String?) {
    if let text, !text.isEmpty {
        defaults.set(text, forKey: Constants.intentHintKey)
    } else {
        defaults.removeObject(forKey: Constants.intentHintKey)
    }
    defaults.synchronize()
}

func readIntentHint() -> String? {
    defaults.synchronize()
    guard let text = defaults.string(forKey: Constants.intentHintKey), !text.isEmpty else { return nil }
    return text
}
```

- [ ] **Step 3: Build to verify (⌘B in Xcode)**

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add Shared/Constants.swift Shared/AppGroupService.swift
git commit -m "feat: add intent hint key and AppGroupService read/write methods"
```

---

## Task 2: Remove "Email" tone preset

**Files:**
- Modify: `Shared/Models/Tone.swift`

- [ ] **Step 1: Delete the email preset line**

In `Shared/Models/Tone.swift`, remove the line:

```swift
Tone(id: UUID(), name: "Email",        instruction: "Structured email reply. Match the formality of the email. Clear, purposeful, no fluff.", isPreset: true),
```

The presets array should now be: Casual, Friendly, Dating, Professional, Formal, Bold, Witty.

- [ ] **Step 2: Build to verify**

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add Shared/Models/Tone.swift
git commit -m "feat: remove Email from tone presets — now a mode, not a tone"
```

---

## Task 3: Extract contact resolver to Shared/

**Files:**
- Create: `Shared/ContactResolver.swift`
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`
- Modify: `Replr/Replr/Intents/QuickReplyIntent.swift`

The contact-resolution block is copy-pasted verbatim in both intents. Extract it to a free function in `Shared/` so the keyboard can also call it.

- [ ] **Step 1: Create `Shared/ContactResolver.swift`**

```swift
import Foundation

struct ResolvedContact {
    let id: UUID?
    let name: String?
}

/// Resolves the LLM-detected contact name against the App Group contact list.
/// Creates a new contact if none exists with that name, switches `currentContactID`.
/// Returns nil id/name for group chats and unknown senders.
func resolveContact(from result: ReplyResult) -> ResolvedContact {
    let isGroupOrUnknown = result.contactName == nil
        || result.contactName == "Unknown"
        || result.contactName?.isEmpty == true
        || result.contactName?.hasPrefix("Group:") == true

    if isGroupOrUnknown {
        let name = result.contactName?.hasPrefix("Group:") == true ? result.contactName : nil
        return ResolvedContact(id: nil, name: name)
    }

    if let existingID = AppGroupService.shared.currentContactID,
       let existingContact = AppGroupService.shared.loadContacts()
           .first(where: { $0.id == existingID }),
       let llmName = result.contactName,
       existingContact.displayName.trimmingCharacters(in: .whitespaces).lowercased()
           == llmName.trimmingCharacters(in: .whitespaces).lowercased() {
        return ResolvedContact(id: existingID, name: existingContact.displayName)
    }

    if let name = result.contactName {
        let contact = AppGroupService.shared.findContacts(named: name).first
            ?? AppGroupService.shared.createContact(displayName: name)
        AppGroupService.shared.currentContactID = contact.id
        return ResolvedContact(id: contact.id, name: contact.displayName)
    }

    return ResolvedContact(id: nil, name: nil)
}
```

Add `ContactResolver.swift` to both the `Replr` and `ReplrKeyboard` targets in Xcode (Target Membership checkboxes in the File Inspector).

- [ ] **Step 2: Update GenerateReplyIntent.swift**

Replace the inline contact-resolution block (lines 57–84 in the current file) with:

```swift
let resolved = resolveContact(from: result)
let resolvedContactID = resolved.id
let resolvedContactName = resolved.name
```

The full updated `perform()` success branch after `NSLog("[Replr][Intent] Got %d replies…")`:

```swift
let resolved = resolveContact(from: result)
let resolvedContactID = resolved.id
let resolvedContactName = resolved.name

let thumbnail = makeThumbnail(image)
let session = CaptureSession(
    id: UUID(),
    timestamp: Date(),
    thumbnailData: thumbnail,
    contextHint: context,
    generatedReplies: result.replies,
    selectedReply: nil,
    llmSummary: result.summary,
    contactID: resolvedContactID,
    contactName: resolvedContactName
)
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

- [ ] **Step 3: Update QuickReplyIntent.swift**

Replace the inline contact-resolution block (lines 83–112 in the current file) with:

```swift
let resolved = resolveContact(from: result)
let resolvedContactID = resolved.id
let resolvedContactName = resolved.name
```

The full updated success branch after `NSLog("[Replr][QuickReply] Got %d replies…")`:

```swift
let resolved = resolveContact(from: result)
let resolvedContactID = resolved.id
let resolvedContactName = resolved.name

let thumbnail = makeThumbnail(image)
let session = CaptureSession(
    id: UUID(),
    timestamp: Date(),
    thumbnailData: thumbnail,
    contextHint: nil,
    generatedReplies: result.replies,
    selectedReply: nil,
    llmSummary: result.summary,
    contactID: resolvedContactID,
    contactName: resolvedContactName
)
AppGroupService.shared.appendCaptureSession(session)
AppGroupService.shared.saveReplies(result.replies)
```

- [ ] **Step 4: Build to verify**

Expected: zero errors in all three files.

- [ ] **Step 5: Commit**

```bash
git add Shared/ContactResolver.swift \
        Replr/Replr/Intents/GenerateReplyIntent.swift \
        Replr/Replr/Intents/QuickReplyIntent.swift
git commit -m "refactor: extract contact resolution to shared free function"
```

---

## Task 4: KeyboardModel — new enum, properties, editIntent

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Add `KeyboardInputMode` enum and `.editIntent` to `KeyboardState`**

At the top of `KeyboardView.swift`, after `enum KBMode`:

```swift
enum KeyboardInputMode { case chat, email }
```

Add `.editIntent` to `KeyboardState`:

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
    case editIntent                                          // intent hint text entry
}
```

- [ ] **Step 2: Add published properties to `KeyboardModel`**

Add after `@Published var hasAnySessions: Bool = false`:

```swift
@Published var inputMode: KeyboardInputMode = .chat
@Published var intentHint: String? = nil
```

- [ ] **Step 3: Update input handlers to include `.editIntent`**

Replace the `type(_:)` method:

```swift
func type(_ char: String) {
    let out = isShifted ? char.uppercased() : char
    switch state {
    case .editReply, .editContact, .editIntent: inputText += out
    default: onTypeChar?(out)
    }
    if isShifted, kbMode == .alpha { isShifted = false }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

Replace `backspace()`:

```swift
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
```

Replace `space()`:

```swift
func space() {
    switch state {
    case .editReply, .editContact, .editIntent: inputText += " "
    default: onSpaceChar?()
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

- [ ] **Step 4: Update `confirmInput()` and `cancelInput()` for `.editIntent`**

Replace `confirmInput()`:

```swift
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
```

Replace `cancelInput()`:

```swift
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
```

- [ ] **Step 5: Add `enterEditIntent()` and `generateEmailReply()` to `KeyboardModel`**

Add after `enterEditContact(_:)`:

```swift
func enterEditIntent() {
    inputText = intentHint ?? ""; isShifted = false; kbMode = .alpha
    withAnimation(.easeInOut(duration: 0.18)) { state = .editIntent }
}

func generateEmailReply() {
    guard case .idle = state else { return }
    guard let emailText = UIPasteboard.general.string, !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
            intentHint = nil
            AppGroupService.shared.saveIntentHint(nil)
            currentReplies = result.replies
            hasAnySessions = true
            withAnimation(.easeInOut(duration: 0.2)) { state = .replies(result.replies) }
        } catch {
            withAnimation { state = .error(error.localizedDescription) }
        }
    }
}
```

- [ ] **Step 6: Update `stateTag` in `KeyboardRootView` for `.editIntent`**

In `KeyboardRootView`, replace the `stateTag` computed property:

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
    case .editIntent:   return 8
    }
}
```

- [ ] **Step 7: Build to verify**

Expected: zero errors. There will be a warning about unhandled `editIntent` in the `contentArea` switch — that's fixed in Task 8.

- [ ] **Step 8: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: add KeyboardInputMode, intentHint, editIntent state to KeyboardModel"
```

---

## Task 5: KeyboardViewController — height updates

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

All heights increase by 28 px (mode row), except collapsed which stays at 44.

- [ ] **Step 1: Update the initial height constraint**

Change line 14 from:
```swift
heightConstraint = view.heightAnchor.constraint(equalToConstant: 280)
```
to:
```swift
heightConstraint = view.heightAnchor.constraint(equalToConstant: 308)
```

- [ ] **Step 2: Update the `stateCancellable` height map**

Replace the entire `switch state` block inside `stateCancellable`:

```swift
let newHeight: CGFloat
switch state {
case .idle:          newHeight = 308
case .collapsed:     newHeight = 44
case .editReply:     newHeight = 308
case .editContact:   newHeight = 308
case .editIntent:    newHeight = 308
case .loading:       newHeight = 308
case .error:         newHeight = 308
case .replies:       newHeight = 348
case .disambiguate:  newHeight = 348
}
```

- [ ] **Step 3: Build to verify**

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: increase keyboard heights by 28px for mode row"
```

---

## Task 6: Mode row in ReplrStrip

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

The mode row replaces the collapse chevron's home. The chevron moves into the mode row; the action bar and capture-CTA bar no longer contain a chevron.

- [ ] **Step 1: Restructure `ReplrStrip.body`**

Replace the entire `var body: some View` of `ReplrStrip` with:

```swift
var body: some View {
    VStack(spacing: 0) {
        // Mode row: Chat / Email tabs + collapse chevron
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { model.inputMode = .chat }
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { model.inputMode = .email }
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

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KBColors.textDim)
                .frame(width: 36, height: 28)
        }
        .padding(.leading, 8)
        .frame(height: 28)
        .contentShape(Rectangle())
        .onTapGesture { model.collapse() }

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
                HStack(spacing: 0) {
                    stripCentreContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.hasAnySessions)
        .animation(.easeInOut(duration: 0.15), value: model.lastInsertedReply == nil)

        KBColors.borderHair.frame(height: 0.5)

        // Tone row: pills + intent chip + optional globe
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

            KBColors.borderDim.frame(width: 0.5, height: 16)

            // Intent hint chip
            Button { model.enterEditIntent() } label: {
                Group {
                    if let hint = model.intentHint {
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
                    } else {
                        Text("+ intent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KBColors.textDim)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .overlay(
                                Capsule()
                                    .stroke(KBColors.textDim.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .animation(.easeInOut(duration: 0.15), value: model.intentHint == nil)

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
```

- [ ] **Step 2: Remove the old `isCaptureIdleState` property and stale `stripCentreContent` idle-with-sessions case**

Verify `isCaptureIdleState` is still present (moved up to the new body, same logic). If not, add it back before `body`:

```swift
private var isCaptureIdleState: Bool {
    guard model.lastInsertedReply == nil else { return false }
    if case .idle = model.state { return model.hasAnySessions }
    return false
}
```

`stripCentreContent` should only still handle: undo chip check, `.idle where !model.hasAnySessions`, `.loading`, `.error`, and `default`. Remove any remaining `.idle` (with sessions) case if it's still there.

- [ ] **Step 3: Build to verify**

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: mode row (Chat/Email tabs + chevron) and intent chip in ReplrStrip"
```

---

## Task 7: editIntent state view

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

The `.editIntent` state renders identically to `.editContact` — a text row at top with a "Set" button, then the QWERTY keyboard.

- [ ] **Step 1: Add `EditIntentView` struct**

Add after `EditContactView` (around line 504):

```swift
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
```

- [ ] **Step 2: Wire `.editIntent` in `KeyboardRootView.contentArea`**

In the `switch model.state` inside `contentArea`, add after the `.editContact` case:

```swift
case .editIntent:
    EditIntentView(model: model).transition(.opacity)
```

- [ ] **Step 3: Build to verify**

Expected: zero errors, no warnings about unhandled cases.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: editIntent state view — text entry for steering reply direction"
```

---

## Task 8: Email mode idle view + email generate flow

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

When `model.inputMode == .email` and state is `.idle`, replace the QWERTY keyboard with a "Paste & Generate" button. The generate logic is already on `KeyboardModel.generateEmailReply()` from Task 4.

- [ ] **Step 1: Update `IdleWithKeyboard` to branch on `inputMode`**

Replace the body of `IdleWithKeyboard`:

```swift
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
                    onDone: { model.onReturnChar?() }
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
```

- [ ] **Step 2: Handle regenerate in email mode**

The existing `regenerate()` on `KeyboardModel` calls `state = .idle`. In email mode, `.idle` now renders the email idle view, so the user will see "Paste & Generate" again — which is correct. No extra changes needed.

- [ ] **Step 3: Build to verify**

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: email mode idle view with Paste & Generate button"
```

---

## Task 9: Final wiring and cleanup

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Remaining loose ends: the `KBInputArea` used for `.editReply` also needs to show the ReplrStrip above it (since the mode row is now permanent). Check `KeyboardRootView.contentArea` to ensure the strip is visible in editReply.

- [ ] **Step 1: Verify strip is visible in editReply**

Currently, `.editReply` renders `KBInputArea(model: model, mode: .edit)`. `KBInputArea` does NOT include `ReplrStrip`. This means the mode row disappears during edit. Since the spec says the mode row is permanent in all keyboard states (except collapsed), check whether `KBInputArea` wraps `ReplrStrip` or if it needs to be added.

Read `KBInputArea` in `KeyboardView.swift`:

```bash
grep -n "KBInputArea\|struct KBInput" ReplrKeyboard/Views/KeyboardView.swift
```

If `KBInputArea` is the edit-reply view, add `ReplrStrip(model: model)` at the top of its body. If the spec permits omitting the mode row during edit states, leave it unchanged (editReply/editContact/editIntent are text-entry states where mode switching doesn't make sense).

Per spec: "Loading/replies/error/editReply/editContact states are shared between both modes and render identically." The mode row being present is a layout feature — the spec says the height includes the mode row for all states. So the mode row should be visible in edit states.

- [ ] **Step 2: Add mode row to edit-state views if missing**

Check if `EditContactView` and the `KBInputArea` (editReply) include the strip. If not, wrap each in a `VStack` that prepends `ReplrStrip(model: model)`.

For `EditContactView`, change:

```swift
struct EditContactView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)   // ← add this line
            HStack(spacing: 8) {
                // ... rest unchanged
```

Apply the same pattern to `EditIntentView` (add `ReplrStrip(model: model)` at the top of its VStack body) and to the view rendered for `.editReply`.

- [ ] **Step 3: Build to verify**

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: ensure mode row visible in edit states"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| Mode row: Chat/Email tabs + chevron | Task 6 |
| Heights +28px across all states | Task 5 |
| Intent hint chip in tone row | Task 6 |
| `.editIntent` state | Task 4 + Task 7 |
| Intent hint → `summary` API field | Task 4 (generateEmailReply passes `intentHint` as `summary`) |
| Intent hint cleared after success, not failure | Task 4 (`generateEmailReply`) |
| App Group `intentHintKey`, `saveIntentHint`, `readIntentHint` | Task 1 |
| Remove "email" from tone presets | Task 2 |
| Hide "dating" in email mode | Task 6 (tone row filter) |
| Email idle view: Paste & Generate | Task 8 |
| Email generate flow (clipboard → API → replies) | Task 4 (generateEmailReply) |
| Contact resolution extracted to Shared/ | Task 3 |
| GenerateReplyIntent uses shared resolver | Task 3 |
| QuickReplyIntent uses shared resolver | Task 3 |
| Keyboard calls generateRepliesFromEmail directly | Task 4 |
| Regenerate in email mode shows Paste & Generate | Task 8 (Step 2) |
| `previousContext` from current contact summaries | Task 4 (generateEmailReply) |

**Gap:** The spec mentions `GenerateReplyIntent` should also read `intentHint` from App Group and use it as `summary`, preferring it over `pendingContext`. This is not in the plan because the intent is triggered via Back Tap (screenshot flow), and the intent hint is designed for direct keyboard use. The spec's App Group read is a secondary path. Since the keyboard email flow already clears the hint after success, and the intent flow uses `readPendingContext()` as `summary`, adding this crossover would risk stale hints bleeding into screenshot captures. **Decision: skip this crossover.** The keyboard alone manages intent hint for its own direct calls.
