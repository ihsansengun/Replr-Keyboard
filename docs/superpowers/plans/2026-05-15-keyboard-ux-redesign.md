# Keyboard UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cryptic idle strip, fix loading/error height jumps, and add a visible send button to reply cards so first-time users immediately know what to do.

**Architecture:** All changes are in `ReplrKeyboard/Views/KeyboardView.swift` and `ReplrKeyboard/KeyboardViewController.swift`. `ReplrStrip` becomes the smart action bar handling idle/newUser/loading/error modes by reading `model.state` directly. `IdleWithKeyboard` is reused for loading and error states so the QWERTY keys are always visible. The companion app gains a `replr://setup` URL handler for the new-user onboarding path.

**Tech Stack:** SwiftUI, UIKit (`UIInputViewController`), Combine, App Group (`UserDefaults`), `AppGroupService`.

---

## File Map

| File | What changes |
|------|-------------|
| `ReplrKeyboard/Views/KeyboardView.swift` | (1) `ReplyCard` — add `↑ Send` button; (2) `KeyboardModel` — add `hasAnySessions`; (3) `ReplrStrip` — smart action bar for idle/newUser/loading/error; (4) `KeyboardRootView.contentArea` — `.loading` and `.error` show `IdleWithKeyboard`; (5) `KeyboardRootView.showToneBar` — remove `.error`; (6) `ErrorStateView` — remove (replaced by strip logic) |
| `ReplrKeyboard/KeyboardViewController.swift` | Height switch: `.loading` → 280, explicit `.error(_)` → 280 |
| `Replr/Replr/App/ReplrApp.swift` | Add `showSetup` state + `replr://setup` URL handler |

---

## Task 1: Add ↑ Send Button to ReplyCard

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `ReplyCard` struct (~line 918)

Context: `ReplyCard` has a bottom-left overlay with only `✎ Edit`. The whole card is tappable to insert (`onTap`) but nothing communicates that. We add `↑ Send` on the left, keeping `✎ Edit` on the right.

- [ ] **Step 1: Open the file and locate ReplyCard**

  Open `ReplrKeyboard/Views/KeyboardView.swift`. Find `struct ReplyCard` — it starts around line 918. The bottom overlay `HStack` currently only has a `Spacer()` + Edit button.

- [ ] **Step 2: Replace the bottom overlay HStack**

  Find this block inside `ReplyCard.body`:

  ```swift
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
  ```

  Replace it with:

  ```swift
  HStack(spacing: 0) {
      Button(action: onTap) {
          HStack(spacing: 3) {
              Image(systemName: "arrow.up").font(.system(size: 10))
              Text("Send").font(.system(size: 11))
          }
          .foregroundColor(KBColors.amber)
      }
      .buttonStyle(.plain)
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
  ```

- [ ] **Step 3: Build and verify**

  Build the `ReplrKeyboard` target in Xcode. Confirm no errors. The reply card now shows `↑ Send` bottom-left and `✎ Edit` bottom-right. Tapping `↑ Send` inserts the reply (same as tapping the card body). Tapping the card body still inserts too.

- [ ] **Step 4: Commit**

  ```bash
  git add ReplrKeyboard/Views/KeyboardView.swift
  git commit -m "feat: add visible Send button to reply card footer"
  ```

---

## Task 2: Add hasAnySessions to KeyboardModel

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `KeyboardModel` class (~line 23)
- Modify: `ReplrKeyboard/KeyboardViewController.swift` — `viewWillAppear`

This property drives the new-user onboarding hint in `ReplrStrip`. It is set in `viewWillAppear` each time the keyboard appears.

- [ ] **Step 1: Add published property to KeyboardModel**

  In `KeyboardModel`, after the `@Published var contactName` line, add:

  ```swift
  @Published var hasAnySessions: Bool = false
  ```

- [ ] **Step 2: Set it in viewWillAppear**

  In `KeyboardViewController.viewWillAppear(_:)`, after the block that resolves `model.contactName`, add:

  ```swift
  model.hasAnySessions = !AppGroupService.shared.loadCaptureSessions().isEmpty
  ```

- [ ] **Step 3: Also update after replies arrive**

  In `KeyboardViewController.startCapturePoll()`, inside the `else if let replies = AppGroupService.shared.consumeReplies()` branch, after the existing `model.currentReplies = replies` line, add:

  ```swift
  self.model.hasAnySessions = true
  ```

- [ ] **Step 4: Build and verify**

  Build `ReplrKeyboard`. No errors. `model.hasAnySessions` is `false` for fresh installs and `true` once any session exists.

- [ ] **Step 5: Commit**

  ```bash
  git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/KeyboardViewController.swift
  git commit -m "feat: track hasAnySessions on KeyboardModel for new-user detection"
  ```

---

## Task 3: ReplrStrip — Smart Action Bar

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `ReplrStrip` struct (~line 1033)

`ReplrStrip` currently shows `"Screenshot → triple-tap"` in its top row. We replace the top row with four adaptive states read from `model.state` and `model.hasAnySessions`:

| Condition | Top row content |
|-----------|----------------|
| `model.state == .loading` | Spinner + "Generating…" + amber progress bar |
| `model.state == .error(msg)` | ⚠ message + "↺ Retry" button |
| `!model.hasAnySessions` | "Open Replr app to set up triple-tap" (static text) |
| otherwise (idle, has sessions) | `[contact \| ↓ Capture replies \| tone]` |

- [ ] **Step 1: Locate ReplrStrip top row**

  Find `struct ReplrStrip` in `KeyboardView.swift`. Its `body` has a `VStack` with two rows. Row 1 is the `HStack` containing the `"Screenshot → triple-tap"` text and `chevron.down` icon. That entire Row 1 `HStack` is what we replace.

- [ ] **Step 2: Add a computed property for strip mode**

  Inside `ReplrStrip`, before `var body`, add:

  ```swift
  private var isLoading: Bool {
      if case .loading = model.state { return true }
      return false
  }

  private var errorMessage: String? {
      if case .error(let msg) = model.state { return msg }
      return nil
  }
  ```

- [ ] **Step 3: Replace Row 1 content**

  Find the Row 1 `HStack` (the one containing the `"Screenshot → triple-tap"` text and `.onTapGesture { model.collapse() }`). Replace the entire Row 1 `HStack` block with:

  ```swift
  Group {
      if isLoading {
          // Loading mode
          HStack(spacing: 8) {
              ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.7)
                  .tint(KBColors.amber)
              Text("Generating…")
                  .font(.system(size: 12))
                  .foregroundColor(KBColors.textDim)
              Spacer()
          }
          .padding(.horizontal, 12)
          .frame(height: 28)
          .overlay(alignment: .bottom) {
              GeometryReader { geo in
                  KBColors.amber
                      .frame(width: geo.size.width * 0.6, height: 2)
                      .offset(x: isLoading ? geo.size.width : -geo.size.width * 0.6)
                      .animation(
                          .linear(duration: 1.2).repeatForever(autoreverses: false),
                          value: isLoading
                      )
              }
              .frame(height: 2)
          }
      } else if let msg = errorMessage {
          // Error mode
          HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle")
                  .font(.system(size: 11))
                  .foregroundColor(KBColors.amber)
              Text(msg)
                  .font(.system(size: 11))
                  .foregroundColor(KBColors.textDim)
                  .lineLimit(1)
                  .truncationMode(.tail)
              Spacer()
              Button {
                  withAnimation(.easeInOut(duration: 0.18)) { model.state = .idle }
              } label: {
                  HStack(spacing: 3) {
                      Image(systemName: "arrow.clockwise").font(.system(size: 10))
                      Text("Retry").font(.system(size: 11, weight: .medium))
                  }
                  .foregroundColor(KBColors.amber)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(KBColors.amberBg)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
          }
          .padding(.horizontal, 12)
          .frame(height: 28)
      } else if !model.hasAnySessions {
          // New user mode
          HStack(spacing: 6) {
              Image(systemName: "hand.tap")
                  .font(.system(size: 11))
                  .foregroundColor(KBColors.amber.opacity(0.7))
              Text("Open Replr app to set up triple-tap")
                  .font(.system(size: 11))
                  .foregroundColor(KBColors.amber.opacity(0.7))
              Spacer()
          }
          .padding(.horizontal, 12)
          .frame(height: 28)
      } else {
          // Normal idle mode — contact | ↓ Capture button | tone shortcut
          HStack(spacing: 6) {
              if let name = model.contactName {
                  Button { model.enterEditContact(name) } label: {
                      Text(name)
                          .font(.system(size: 11, weight: .semibold))
                          .foregroundColor(KBColors.amber)
                          .lineLimit(1)
                  }
                  .buttonStyle(.plain)
              }

              Spacer()

              Button { model.collapse() } label: {
                  HStack(spacing: 4) {
                      Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                      Text("Capture replies").font(.system(size: 11, weight: .semibold))
                  }
                  .foregroundColor(.black)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(KBColors.amber)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)

              Spacer()

              Button { model.selectTone(model.selectedTone) } label: {
                  Text(model.selectedTone.name)
                      .font(.system(size: 11))
                      .foregroundColor(KBColors.textDim)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 3)
                      .background(KBColors.surface)
                      .clipShape(Capsule())
              }
              .buttonStyle(.plain)
          }
          .padding(.horizontal, 12)
          .frame(height: 28)
          .contentShape(Rectangle())
      }
  }
  .animation(.easeInOut(duration: 0.18), value: isLoading)
  .animation(.easeInOut(duration: 0.18), value: model.hasAnySessions)
  ```

  Also remove the existing `.onTapGesture { model.collapse() }` and the `"Use as context"` button block and the `chevron.down` icon — they were part of the old Row 1. The `pendingContext` / "Use as context" flow moves entirely to the collapsed strip (`CollapsedBar`) — it's already there as `model.useAsContext()`. If "Use as context" was needed in the idle strip before, it's no longer needed in the action bar strip.

- [ ] **Step 4: Build and verify**

  Build `ReplrKeyboard`. Run on simulator:
  - With no sessions: strip shows "Open Replr app to set up triple-tap"
  - With sessions: strip shows `[contact name] [↓ Capture replies] [tone]`
  - Tapping "↓ Capture replies" collapses the keyboard to the 44px strip

- [ ] **Step 5: Commit**

  ```bash
  git add ReplrKeyboard/Views/KeyboardView.swift
  git commit -m "feat: smart action bar in ReplrStrip — idle, loading, error, new-user modes"
  ```

---

## Task 4: Loading & Error — Full Keyboard Height

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift` — height switch (~line 112)
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — `KeyboardRootView.contentArea` and `showToneBar`

Since `ReplrStrip` now handles loading and error display, we swap `GeneratingView`/`ErrorStateView` for `IdleWithKeyboard` in the content area, and fix the height constants.

- [ ] **Step 1: Fix height constants in KeyboardViewController**

  Find the `stateCancellable` sink in `KeyboardViewController.viewDidLoad`. The switch currently reads:

  ```swift
  case .loading:       newHeight = 50
  ...
  default:             newHeight = 220  // error state
  ```

  Change those two lines to:

  ```swift
  case .loading:       newHeight = 280
  ...
  case .error:         newHeight = 280
  ```

  Remove the `default` fallback (or keep it for any future states — if kept, change the comment to `// fallback`).

- [ ] **Step 2: Update contentArea in KeyboardRootView**

  Find `private var contentArea: some View` in `KeyboardRootView`. Replace:

  ```swift
  case .loading:
      GeneratingView().transition(.opacity)
  ```

  with:

  ```swift
  case .loading:
      IdleWithKeyboard(model: model).transition(.opacity)
  ```

  Then replace:

  ```swift
  case .error(let msg):
      ErrorStateView(message: msg).transition(.opacity)
  ```

  with:

  ```swift
  case .error:
      IdleWithKeyboard(model: model).transition(.opacity)
  ```

  (The error message is now rendered inside `ReplrStrip` which `IdleWithKeyboard` includes.)

- [ ] **Step 3: Remove .error from showToneBar**

  Find `private var showToneBar: Bool`. Change:

  ```swift
  case .replies, .error: return true
  ```

  to:

  ```swift
  case .replies: return true
  ```

- [ ] **Step 4: Build and verify**

  Build and run in Simulator. Trigger a generation (set `AppGroupService.shared.isGenerating = true` in a test or via BackTap). Confirm:
  - During loading: keyboard stays full-height (280px), spinner shows in action bar row, QWERTY keys visible
  - On error: keyboard stays full-height (280px), ⚠ message + Retry in action bar, tapping Retry resets to idle
  - No layout jump during state transitions

- [ ] **Step 5: Commit**

  ```bash
  git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/KeyboardViewController.swift
  git commit -m "feat: keep keyboard full height during loading and error states"
  ```

---

## Task 5: Companion App — replr://setup URL Scheme

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`

The keyboard's new-user strip says "Open Replr app to set up triple-tap". When the user opens the companion app (manually), they should be able to reach the BackTap setup screen. We add a `replr://setup` deep link that opens it directly. `BackTapSetupStep` already exists in `OnboardingView.swift`.

- [ ] **Step 1: Add showSetup state to ReplrApp**

  In `struct ReplrApp`, add alongside `@State private var showCapture`:

  ```swift
  @State private var showSetup = false
  ```

- [ ] **Step 2: Add fullScreenCover for setup**

  In `ContentView()`, after the existing `.fullScreenCover(isPresented: $showCapture)` modifier, add:

  ```swift
  .fullScreenCover(isPresented: $showSetup) {
      BackTapSetupFullView(isPresented: $showSetup)
  }
  ```

- [ ] **Step 3: Handle replr://setup in onOpenURL**

  Find `.onOpenURL { url in`. It currently handles `replr://capture`. Add the setup case:

  ```swift
  .onOpenURL { url in
      guard url.scheme == "replr" else { return }
      if url.host == "capture" { showCapture = true }
      if url.host == "setup"   { showSetup = true }
  }
  ```

- [ ] **Step 4: Create BackTapSetupFullView**

  In `Replr/Replr/App/ReplrApp.swift`, add this view below `CaptureView`:

  ```swift
  struct BackTapSetupFullView: View {
      @Binding var isPresented: Bool

      var body: some View {
          NavigationStack {
              BackTapSetupStep(onNext: { isPresented = false })
                  .navigationTitle("Set Up Triple-Tap")
                  .navigationBarTitleDisplayMode(.inline)
                  .toolbar {
                      ToolbarItem(placement: .cancellationAction) {
                          Button("Close") { isPresented = false }
                      }
                  }
          }
      }
  }
  ```

  `BackTapSetupStep` is already defined in `Replr/Replr/Features/Onboarding/OnboardingView.swift` and is accessible from the same target.

- [ ] **Step 5: Build and verify**

  Build the `Replr` target. Run companion app. In Safari on simulator, navigate to `replr://setup` — the BackTap setup screen should appear as a full screen cover with a Close button.

- [ ] **Step 6: Commit**

  ```bash
  git add Replr/Replr/App/ReplrApp.swift
  git commit -m "feat: handle replr://setup deep link to open BackTap setup screen"
  ```

---

## Self-Review Checklist

- [x] **Spec §1 (Idle action bar):** Task 3 implements `↓ Capture replies` button that collapses keyboard. New-user hint covered.
- [x] **Spec §2 (Capture flow / onboarding):** Task 2 + 3 detect empty sessions. Task 5 adds `replr://setup`. Keyboard shows static hint (can't open URLs from keyboard extension sandbox).
- [x] **Spec §3 (Loading state full height):** Task 4 changes height to 280 and shows `IdleWithKeyboard`.
- [x] **Spec §4 (Error state full height + retry):** Task 4 changes height to 280. Retry button in `ReplrStrip` resets to `.idle`.
- [x] **Spec §5 (Reply card send):** Task 1 adds `↑ Send` button.
- [x] **No TBDs or placeholders** — all code shown.
- [x] **Type consistency** — `KBColors.amber`, `KBColors.amberBg`, `KBColors.surface`, `KBColors.textDim` used consistently across tasks (these are defined in `KeyboardView.swift` `struct KBColors`).
- [x] **`model.collapse()`** exists in `KeyboardModel` (line 126 in `KeyboardView.swift`).
- [x] **`model.enterEditContact(_:)`** exists (line 121) — used in Task 3 for contact tap.
