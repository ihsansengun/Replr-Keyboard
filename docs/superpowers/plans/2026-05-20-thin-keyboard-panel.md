# Thin Keyboard Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the full custom QWERTY keyboard extension with a thin AI panel so Replr works as a daily-driver tool alongside any system keyboard in any language.

**Architecture:** The `ReplrKeyboard` extension drops its custom key input entirely. It shows a 240px idle panel (capture zone + last contact preview), transitions to a vertical reply list when replies arrive, then auto-switches back to the system keyboard 1.5s after the user taps Send. Edit pre-fills the reply into the text field and switches immediately. Back Tap → `GenerateReplyIntent` is the only capture trigger — it works from any active keyboard.

**Tech Stack:** Swift 5.9, SwiftUI, UIInputViewController, AppGroup UserDefaults, Combine

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| **Delete** | `ReplrKeyboard/Views/IdleView.swift` | Legacy UIKit idle (unused) |
| **Delete** | `ReplrKeyboard/Views/LoadingView.swift` | Legacy UIKit loading (unused) |
| **Delete** | `ReplrKeyboard/Views/ReplyCardsView.swift` | Legacy UIKit carousel (unused) |
| **Delete** | `ReplrKeyboard/Views/ReplyCardView.swift` | Legacy UIKit reply card (unused) |
| **Delete** | `ReplrKeyboard/Views/ToneSelectorView.swift` | Legacy UIKit tone picker (unused) |
| **Modify** | `ReplrKeyboard/Views/KeyboardView.swift` | State enum, model, strip, colors, disambiguate |
| **Modify** | `ReplrKeyboard/KeyboardViewController.swift` | Callbacks, insert, undo, auto-switch |
| **Create** | `ReplrKeyboard/Views/IdlePanelView.swift` | Capture zone + last capture preview |
| **Create** | `ReplrKeyboard/Views/ReplyListView.swift` | Vertical reply list + row component |

---

## Task 1: Delete dead UIKit view files

All five `UIView` subclasses in `ReplrKeyboard/Views/` predate the SwiftUI rewrite and are not referenced anywhere in the current codebase.

- [ ] **Delete the five files**

```bash
rm ReplrKeyboard/Views/IdleView.swift \
   ReplrKeyboard/Views/LoadingView.swift \
   ReplrKeyboard/Views/ReplyCardsView.swift \
   ReplrKeyboard/Views/ReplyCardView.swift \
   ReplrKeyboard/Views/ToneSelectorView.swift
```

- [ ] **Remove them from the Xcode project**

Open `Replr/Replr.xcodeproj` in Xcode. In the Project Navigator, select each of the five deleted files (they will show in red), right-click → **Delete** → **Remove Reference**. Verify the `ReplrKeyboard` target's Compile Sources no longer lists them (Build Phases tab).

- [ ] **Build to confirm no errors**

In Xcode: **⌘B**. Expected: Build Succeeded with no errors about missing files.

- [ ] **Commit**

```bash
git add -A
git commit -m "chore: delete dead UIKit keyboard views (pre-SwiftUI era)"
```

---

## Task 2: Simplify KeyboardState enum

Remove the three states that depended on the custom QWERTY. The compiler errors that follow guide the rest of the cleanup.

**File:** `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Replace the KeyboardState enum** (currently lines 80–89)

```swift
enum KeyboardState: Equatable {
    case idle
    case loading
    case replies([String])
    case error(String)
    case disambiguate(name: String, candidates: [Contact])
}
```

- [ ] **Remove the KBMode enum** (currently around line 91: `enum KBMode { case alpha, numeric }`)

Delete the entire line.

- [ ] **Build to see all compiler errors**

**⌘B** — note every error location. Do NOT fix them yet; they map exactly to what the next tasks remove.

- [ ] **Commit the enum change only**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "refactor: remove collapsed/editReply/editContact/KBMode from KeyboardState"
```

---

## Task 3: Strip QWERTY properties and methods from KeyboardModel

Remove all properties and methods that served the custom key input. Add `onEditReply` for the new pre-fill flow.

**File:** `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Remove these `@Published` properties from KeyboardModel**

Delete the following lines:
```swift
@Published var inputText: String = ""
@Published var isShifted: Bool = false
@Published var kbMode: KBMode = .alpha
```

- [ ] **Remove these callback vars from KeyboardModel**

Delete:
```swift
var onTypeChar: ((String) -> Void)?
var onDeleteChar: (() -> Void)?
var onSpaceChar: (() -> Void)?
var onReturnChar: (() -> Void)?
var onConfirmContact: ((String) -> Void)?
var onDifferentPerson: ((String) -> Void)?
```

- [ ] **Add the new onEditReply callback** (after `var onUndoInsert`)

```swift
var onEditReply: ((String) -> Void)?
```

- [ ] **Remove these methods from KeyboardModel**

Delete the entire bodies of: `type(_:)`, `backspace()`, `space()`, `toggleShift()`, `toggleMode()`, `confirmInput()`, `cancelInput()`, `enterEditReply(_:)`, `enterEditContact(_:)`.

- [ ] **Simplify useAsContext()** — remove the `collapse()` call

Replace the current `useAsContext()` with:
```swift
func useAsContext() {
    onUseAsContext?()
    pendingContext = ""
}
```

- [ ] **Simplify collapse()** — delete the method entirely

The `.collapsed` state no longer exists. Delete:
```swift
func collapse() {
    withAnimation(.easeInOut(duration: 0.2)) { state = .collapsed }
}
```

- [ ] **Add editReply helper method** (after `selectReply`)

```swift
func editReply(_ text: String) {
    onEditReply?(text)
}
```

- [ ] **Build** — expect remaining errors in KeyboardRootView and KeyboardViewController only

**⌘B**

- [ ] **Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "refactor: strip QWERTY properties/methods from KeyboardModel, add onEditReply"
```

---

## Task 4: Create IdlePanelView.swift

The full 240px panel shown when Replr is active but no replies exist yet.

**File:** `ReplrKeyboard/Views/IdlePanelView.swift` (new)

- [ ] **Create the file**

```swift
import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            ReplrStrip(model: model)
            VStack(spacing: 8) {
                captureZone
                if model.hasAnySessions {
                    lastCaptureCard
                }
            }
            .padding(10)
            Spacer(minLength: 0)
        }
    }

    private var captureZone: some View {
        VStack(spacing: 6) {
            Text("✦")
                .font(.system(size: 20))
                .foregroundColor(KBColors.accent)
            Text("Back Tap to capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KBColors.accent)
            Text("screenshot → AI replies")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    KBColors.accent.opacity(0.33),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
        )
    }

    private var lastCaptureCard: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(KBColors.surface)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(model.contactName.map { String($0.prefix(1)).uppercased() } ?? "?")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KBColors.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                if let name = model.contactName {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KBColors.textPrimary)
                }
                if let summary = lastSummary {
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundColor(KBColors.textDim)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KBColors.borderHair, lineWidth: 0.5)
        )
    }

    private var lastSummary: String? {
        guard let id = AppGroupService.shared.currentContactID else { return nil }
        return AppGroupService.shared.recentSummaries(forContactID: id, limit: 1).first
    }
}
```

- [ ] **Add the file to the Xcode project**

In Xcode, right-click `ReplrKeyboard/Views` group in the Project Navigator → **Add Files to "Replr"** → select `IdlePanelView.swift` → ensure only the `ReplrKeyboard` target is checked → **Add**.

- [ ] **Build**

**⌘B** — expect no new errors from this file. Existing errors from Task 2/3 still present.

- [ ] **Commit**

```bash
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "feat: add IdlePanelView — capture zone + last contact preview"
```

---

## Task 5: Create ReplyListView.swift

Vertical scrollable list of reply rows, each with Send (↑) and Edit buttons.

**File:** `ReplrKeyboard/Views/ReplyListView.swift` (new)

- [ ] **Create the file**

```swift
import SwiftUI

struct ReplyListView: View {
    let replies: [String]
    let onSend: (String) -> Void
    let onEdit: (String) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                    ReplyRowView(
                        text: reply,
                        onSend: { onSend(reply) },
                        onEdit: { onEdit(reply) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }
}

struct ReplyRowView: View {
    let text: String
    let onSend: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(KBColors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Edit", action: onEdit)
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(KBColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .buttonStyle(.plain)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KBColors.accentFg)
                    .frame(width: 28, height: 28)
                    .background(KBColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KBColors.borderHair, lineWidth: 0.5)
        )
    }
}
```

- [ ] **Add the file to the Xcode project**

In Xcode, right-click `ReplrKeyboard/Views` group → **Add Files** → select `ReplyListView.swift` → only `ReplrKeyboard` target checked → **Add**.

- [ ] **Build**

**⌘B**

- [ ] **Commit**

```bash
git add ReplrKeyboard/Views/ReplyListView.swift
git commit -m "feat: add ReplyListView — vertical reply list with Send and Edit per row"
```

---

## Task 6: Update KeyboardRootView and remove dead view structs

Rewire `KeyboardRootView`'s switch statement to use the new views, add inline loading/error bodies, and update the height map.

**File:** `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Replace the entire `KeyboardRootView` struct** with the following

Find the `// MARK: - Root View` section and replace `struct KeyboardRootView` entirely:

```swift
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
```

- [ ] **Delete the dead view structs** from `KeyboardView.swift`

Remove the entire definitions of each of the following structs/classes (search by `// MARK:` or struct name):

- `struct IdleWithKeyboard`
- `struct CollapsedBar`
- `struct KBInputArea`
- `enum KBInputMode` — **keep** `KeyboardInputMode` (chat/email), delete `KBInputMode` only if it's a duplicate
- `struct EditContactView`
- `struct ReplrKeyboard` — the full QWERTY view
- `private struct CharKey`
- `private struct ShiftKey`
- `private class RepeatTimer`
- `private struct DeleteKey`
- `private struct SpaceKey`
- `private struct ModeKey`
- `private struct DoneKey`
- `struct ReplyCarousel`
- `struct ReplyCard`
- `struct PageDots`
- `struct StepRow`
- `struct IdleStateView`
- `struct GeneratingView`

Keep: `KBColors`, `TonePill`, `ReplrStrip`, `DisambiguateView`, `SkeletonLine`, `ErrorStateView` (if referenced — can delete if not), custom mode icons (`ChatIcon`, `EmailIcon`, `IntentIcon`), `KeyboardInputMode`, `KeyboardState`, `KeyboardModel`, `KeyboardRootView`.

- [ ] **Build**

**⌘B** — target: zero errors. Fix any remaining symbol references that weren't caught by the above removals.

- [ ] **Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "refactor: rewire KeyboardRootView to thin panel views, delete QWERTY structs"
```

---

## Task 7: Update KeyboardViewController

Remove deleted callbacks, wire `onEditReply`, implement auto-switch after Send with cancellable undo timer, and fix the height map.

**File:** `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Add `autoSwitchTask` property** after `heightConstraint`:

```swift
private var autoSwitchTask: DispatchWorkItem?
```

- [ ] **Remove these callback wiring blocks** from `viewDidLoad` (delete each closure assignment):

```swift
model.onTypeChar   = ...
model.onDeleteChar = ...
model.onSpaceChar  = ...
model.onReturnChar = ...
model.onConfirmContact = ...
model.onDifferentPerson = ...
```

- [ ] **Add `onEditReply` wiring** in `viewDidLoad`, after the existing `model.onUndoInsert` line:

```swift
model.onEditReply = { [weak self] reply in
    guard let self else { return }
    let ctx = self.textDocumentProxy.documentContextBeforeInput ?? ""
    for _ in ctx.unicodeScalars { self.textDocumentProxy.deleteBackward() }
    self.textDocumentProxy.insertText(reply)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    self.advanceToNextInputMode()
}
```

- [ ] **Replace the `insert(_:)` method** with the auto-switch version:

```swift
private func insert(_ text: String) {
    let ctx = textDocumentProxy.documentContextBeforeInput ?? ""
    for _ in ctx.unicodeScalars { textDocumentProxy.deleteBackward() }
    textDocumentProxy.insertText(text)
    model.pendingContext = ""
    AppGroupService.shared.savePendingContext("")
    AppGroupService.shared.markLastSessionReplySelected(text)
    AppGroupService.shared.saveIntentHint(nil)
    model.intentHint = nil
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    model.lastInsertedReply = text

    autoSwitchTask?.cancel()
    let task = DispatchWorkItem { [weak self] in
        guard let self, self.model.lastInsertedReply != nil else { return }
        self.model.lastInsertedReply = nil
        self.advanceToNextInputMode()
    }
    autoSwitchTask = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
}
```

- [ ] **Replace `undoLastInsert()`** to cancel the auto-switch timer:

```swift
private func undoLastInsert() {
    guard let text = model.lastInsertedReply else { return }
    for _ in text { textDocumentProxy.deleteBackward() }
    model.lastInsertedReply = nil
    autoSwitchTask?.cancel()
    autoSwitchTask = nil
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
```

- [ ] **Replace the height switch in `stateCancellable`** (the `sink` closure in `viewDidLoad`):

```swift
stateCancellable = model.$state
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        guard let self else { return }
        let height: CGFloat
        switch state {
        case .idle:                       height = 240
        case .loading:                    height = 160
        case .error:                      height = 160
        case .disambiguate:               height = 280
        case .replies(let replies):
            height = min(320, 68 + 12 + CGFloat(replies.count) * 52)
        }
        self.setHeight(height)
    }
```

Note: the old sink observed `Publishers.CombineLatest(model.$state, model.$inputMode)` — simplify it to just `model.$state` as above since `inputMode` no longer affects height.

- [ ] **Remove `updateHeightFromContent()`** — the method is replaced by the formula above. Delete the entire method.

- [ ] **Remove `triggerRetry()`** — check if still referenced. If `model.retryTrigger` is still wired, keep it. Otherwise delete.

Actually — `model.retryTrigger = { [weak self] in self?.triggerRetry() }` is still needed for the error state Retry button. Keep `triggerRetry()` and its wiring.

- [ ] **Build and verify zero errors**

**⌘B**

- [ ] **Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: wire onEditReply, auto-switch after send (1.5s undo window), update height map"
```

---

## Task 8: Manual verification in simulator

No automated tests exist for the keyboard extension UI. Verify each state by running in Simulator.

- [ ] **Run on iPhone 15 Pro simulator, iOS 17+**

In Xcode, select the `Replr` scheme, iPhone 15 Pro simulator, **⌘R**.

- [ ] **Install the keyboard**

Settings → General → Keyboard → Keyboards → Add New Keyboard → Replr.

- [ ] **Verify idle state**

Open Messages app, tap the text field, globe to Replr. Confirm:
- Panel is ~240px tall
- Capture zone shows "✦ Back Tap to capture"
- No QWERTY visible
- Globe key visible in tone row

- [ ] **Verify Back Tap → loading → replies flow**

Simulate Back Tap (Shortcuts app or triple-tap shortcut). Confirm:
- Panel transitions to loading (skeleton lines, ~160px)
- After replies arrive, vertical list appears with Send (↑) and Edit buttons per row
- Panel height grows with number of replies, capped at 320px

- [ ] **Verify Send flow**

Tap ↑ on a reply. Confirm:
- Reply inserted into Messages text field
- Undo chip visible in strip for ~1.5s
- After 1.5s, keyboard switches back to system keyboard automatically

- [ ] **Verify Undo**

Tap ↑, then immediately tap Undo chip before 1.5s. Confirm:
- Reply text deleted from text field
- Keyboard does NOT auto-switch (stays on Replr)

- [ ] **Verify Edit flow**

Tap Edit on a reply. Confirm:
- Reply text appears pre-filled in the text field
- Keyboard switches immediately to system keyboard
- Text is editable normally

- [ ] **Verify error state**

Disconnect network, trigger capture. Confirm:
- Error panel shows at ~160px
- Error message and Retry button visible

- [ ] **Commit any fixes found during verification**

```bash
git add -A
git commit -m "fix: manual verification corrections"
```

---

## Self-Review Checklist (completed inline)

- **Spec coverage**: ✓ All five states covered (idle, loading, replies, error, disambiguate). ✓ Auto-switch after send. ✓ Edit pre-fill. ✓ No QWERTY. ✓ Back Tap only capture. ✓ Dead UIKit files deleted. ✓ Contact chip read-only in replies state.
- **Placeholder scan**: No TBDs or vague steps. Every code block is complete.
- **Type consistency**: `KBColors`, `ReplrStrip`, `AppGroupService`, `KeyboardModel`, `Tone` — all used consistently across tasks. `onEditReply` defined in Task 3, wired in Task 7.
- **One gap noted**: `DisambiguateView` is kept in `KeyboardView.swift` but its entry point (`onDifferentPerson` via `EditContactView`) is removed. The state remains in the enum and view code but is unreachable in this iteration — acceptable for a first ship; re-trigger via contact chip tap can be added in a follow-up.
