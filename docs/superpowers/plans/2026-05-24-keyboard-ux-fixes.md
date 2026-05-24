# Keyboard UX Fixes — Round 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 6 UX issues in the ReplrKeyboard extension — stale contact name, dead space in reply cards, hidden reset button, black keyboard background, and collapsed-bar interaction/copy.

**Architecture:** All changes are confined to the keyboard extension and one shared service. No backend, no app target, no new files — targeted edits to 5 existing files. Each task is independent and can be built/tested incrementally.

**Tech Stack:** Swift, SwiftUI, UIKit (UIInputViewController), App Group UserDefaults.

---

## Files Modified

| File | What changes |
|---|---|
| `Shared/AppGroupService.swift` | Add `func synchronize()` public helper |
| `ReplrKeyboard/KeyboardViewController.swift` | `view.backgroundColor = .clear`; reply heights 320→270 / 380→275; call `synchronize()` before contact read in `viewWillAppear` and poll |
| `ReplrKeyboard/Views/KeyboardView.swift` | `KeyboardRootView`: swap `.bg` for `.regularMaterial`; `CollapsedStripView`: pill handle, xmark→chevron.up, whole-card tap |
| `ReplrKeyboard/Views/RepliesPanelView.swift` | Header: add ↺ button + ReplrMark; carousel: fix to 88pt height; tone strip: remove ↺ button |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Replace `chatContent` with instructional card; triple-tap→double-tap copy throughout |

---

## Task 1: Fix stale contact name (Issue 1)

**Files:**
- Modify: `Shared/AppGroupService.swift`
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

The poll calls `consumeReplies()` (which synchronizes at the start), then reads `currentContactID`. In `viewWillAppear` there is no synchronize before reading `currentContactID` at all. Adding explicit syncs at both read sites closes the race window where the intent writes the contact ID after the keyboard's last sync point.

- [ ] **Step 1: Add public `synchronize()` to AppGroupService**

Open `Shared/AppGroupService.swift`. After `consumeReplies()`, add:

```swift
/// Call this in the keyboard process before reading any value the intent process may have just written.
func synchronize() {
    defaults.synchronize()
}
```

- [ ] **Step 2: Synchronize before contact read in `viewWillAppear`**

Open `ReplrKeyboard/KeyboardViewController.swift`. In `viewWillAppear`, the block that reads `currentContactID` currently has no sync:

```swift
// Resolve contact display name from App Group
if let id = AppGroupService.shared.currentContactID,
```

Add a `synchronize()` call immediately before it:

```swift
// Resolve contact display name from App Group
AppGroupService.shared.synchronize()
if let id = AppGroupService.shared.currentContactID,
   let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
    model.contactName = contact.displayName
} else {
    model.contactName = nil
}
```

- [ ] **Step 3: Synchronize before contact read in the capture poll**

In the same file, inside `startCapturePoll()`, find the block after `consumeReplies()` that reads `currentContactID`:

```swift
// Refresh contact chip — intent may have switched contact during this capture
if let id = AppGroupService.shared.currentContactID,
```

Add a `synchronize()` call immediately before it:

```swift
// Refresh contact chip — intent may have switched contact during this capture
AppGroupService.shared.synchronize()
if let id = AppGroupService.shared.currentContactID,
   let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
    self.model.contactName = contact.displayName
} else {
    self.model.contactName = nil
}
```

- [ ] **Step 4: Build and verify**

In Xcode, build the `ReplrKeyboard` scheme (⌘B). Confirm no errors.

- [ ] **Step 5: Commit**

```bash
git add Shared/AppGroupService.swift ReplrKeyboard/KeyboardViewController.swift
git commit -m "fix: sync App Group defaults before reading contactID to eliminate stale contact name"
```

---

## Task 2: Eliminate dead space in reply cards (Issue 2)

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

The `TabView` inside `ReplyCarouselView` expands to fill all remaining VStack height, leaving empty space below short replies. Fix: constrain the carousel to 88pt and reduce total keyboard height.

- [ ] **Step 1: Constrain `ReplyCarouselView` height**

Open `ReplrKeyboard/Views/RepliesPanelView.swift`. Find the `ReplyCarouselView` call:

```swift
// Reply carousel
ReplyCarouselView(
    replies: replies,
    lastInsertedReply: model.lastInsertedReply,
    currentPage: $currentPage
)
```

Add a fixed height frame:

```swift
// Reply carousel
ReplyCarouselView(
    replies: replies,
    lastInsertedReply: model.lastInsertedReply,
    currentPage: $currentPage
)
.frame(height: 88)
```

- [ ] **Step 2: Reduce keyboard height for replies state**

Open `ReplrKeyboard/KeyboardViewController.swift`. Find:

```swift
case .replies:
    height = inputMode == .email ? 380 : 320
```

Change to:

```swift
case .replies:
    height = inputMode == .email ? 275 : 270
```

- [ ] **Step 3: Build**

Build `ReplrKeyboard` (⌘B). Confirm no errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/RepliesPanelView.swift ReplrKeyboard/KeyboardViewController.swift
git commit -m "fix: constrain reply carousel to 88pt and reduce keyboard height to eliminate dead space"
```

---

## Task 3: Move reset button to replies header (Issue 3)

**Files:**
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

The `↺` button is buried at the right end of the tone strip and hidden by the gradient mask. Move it to the top header row, right of the segmented control.

- [ ] **Step 1: Add `↺` button and `ReplrMark` to the header HStack**

Open `ReplrKeyboard/Views/RepliesPanelView.swift`. Find the header HStack at the top of `body`:

```swift
// Mode segmented control only — tone moves to bottom
HStack {
    ModeSegmentedControl(model: model)
    Spacer()
}
.padding(.horizontal, 16)
.padding(.bottom, 4)
.background(ReplrTheme.Color.bg)
.overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }
```

Replace it with:

```swift
// Mode segmented control + reset + mark
HStack(spacing: 0) {
    ModeSegmentedControl(model: model)
    Spacer()
    Button { model.regenerate() } label: {
        Image(systemName: "arrow.counterclockwise")
            .font(.system(size: 13))
            .foregroundColor(ReplrTheme.Color.textSecondary)
            .frame(width: 36, height: 36)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("New replies")
    ReplrMark(size: 14)
        .padding(.leading, 4)
        .padding(.trailing, 16)
}
.padding(.leading, 16)
.padding(.bottom, 4)
.background(ReplrTheme.Color.bg)
.overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }
```

- [ ] **Step 2: Remove `↺` button from tone strip**

In the same file, find `toneRow` (a computed var). It ends with:

```swift
ReplrTheme.Color.borderStrong.frame(width: 0.5, height: 16)

Button { model.regenerate() } label: {
    Image(systemName: "arrow.counterclockwise")
        .font(.system(size: 13))
        .foregroundColor(ReplrTheme.Color.textSecondary)
        .frame(width: 40, height: 38)
}
.buttonStyle(.plain)
.accessibilityLabel("New replies")

if model.needsGlobeKey {
```

Remove the separator and button, keeping only the globe key block:

```swift
if model.needsGlobeKey {
    ReplrTheme.Color.borderStrong.frame(width: 0.5, height: 16)
    Button { model.onSwitchKeyboard?() } label: {
        Image(systemName: "globe")
            .font(.system(size: 14))
            .foregroundColor(ReplrTheme.Color.textSecondary)
            .frame(width: 36, height: 38)
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Build**

Build `ReplrKeyboard` (⌘B). Confirm no errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "fix: move reset button from tone strip to replies header row"
```

---

## Task 4: Blend keyboard background with system chrome (Issue 4)

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

The keyboard extension's root view has an opaque near-black background that doesn't match the native iOS keyboard chrome. Setting it to `clear` + applying `.regularMaterial` in SwiftUI gives the frosted-glass translucency that matches the system keyboard.

- [ ] **Step 1: Clear the UIKit root view background**

Open `ReplrKeyboard/KeyboardViewController.swift`. In `viewDidLoad`, after the `heightConstraint` setup, add:

```swift
view.backgroundColor = .clear
```

The `hostingVC.view.backgroundColor = .clear` line is already present — this change makes the outer UIInputViewController view transparent too.

- [ ] **Step 2: Replace `KeyboardRootView` background with material**

Open `ReplrKeyboard/Views/KeyboardView.swift`. Find the end of `KeyboardRootView.body`:

```swift
.animation(.easeInOut(duration: 0.2), value: stateTag)
.background(ReplrTheme.Color.bg)
.ignoresSafeArea()
```

Change `.background(ReplrTheme.Color.bg)` to `.background(.regularMaterial)`:

```swift
.animation(.easeInOut(duration: 0.2), value: stateTag)
.background(.regularMaterial)
.ignoresSafeArea()
```

`.regularMaterial` adapts to dark/light mode and gives the frosted-glass look of the native system keyboard. Each panel view's own `.background(ReplrTheme.Color.bg)` still renders on top for all full-height states — the material is only visible behind the collapsed strip card.

- [ ] **Step 3: Clear `CollapsedStripView` outer background**

In the same file, find `CollapsedStripView.body`. At the end of the VStack:

```swift
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
.background(ReplrTheme.Color.bg)
.onAppear {
```

Change to `.background(Color.clear)` so the `KeyboardRootView` material shows through:

```swift
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
.background(Color.clear)
.onAppear {
```

- [ ] **Step 4: Build**

Build `ReplrKeyboard` (⌘B). Confirm no errors.

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "fix: use regularMaterial background so keyboard blends with native iOS chrome"
```

---

## Task 5: Collapsed bar — chevron, pill handle, tap-to-expand (Issue 5)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Replace the isolated `xmark` button with a `chevron.up` indicator. Add a pill handle above the card. Make the entire card a single tappable button.

- [ ] **Step 1: Rewrite `CollapsedStripView.body`**

Open `ReplrKeyboard/Views/KeyboardView.swift`. Find the entire `CollapsedStripView.body`. Replace it with:

```swift
var body: some View {
    VStack(spacing: 0) {
        // Coachmark — first run only
        if showCoachmark {
            CoachmarkBalloon()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .transition(.opacity.animation(ReplrTheme.Motion.coachmark))
        }

        // Pill handle
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)

        // Capture card — entire card is the tap target
        Button {
            dismissCoachmark()
            withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
        } label: {
            HStack(spacing: 10) {
                TapGlyph()

                VStack(alignment: .leading, spacing: 1) {
                    Text("Double-tap the back of your phone")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textPrimary)
                    Text("to capture this chat")
                        .font(.system(size: 11.5))
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .padding(.vertical, 10)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .background(ReplrTheme.Color.surface)
            .overlay(alignment: .leading) {
                ReplrTheme.Color.accent.frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ReplrTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.clear)
    .onAppear {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)
        defaults?.synchronize()
        let seen = defaults?.bool(forKey: coachmarkKey) ?? false
        if !seen {
            withAnimation(ReplrTheme.Motion.coachmark) { showCoachmark = true }
        }
    }
    .onDisappear {
        dismissCoachmark()
    }
}
```

- [ ] **Step 2: Update `CoachmarkBalloon` copy (triple→double)**

In the same file, find `CoachmarkBalloon.body`:

```swift
Text("① Keyboard's minimised. ② Triple-tap the back.")
```

Change to:

```swift
Text("① Keyboard's minimised. ② Double-tap the back.")
```

Also update the `accessibilityLabel`:

```swift
.accessibilityLabel("Coachmark: Keyboard's minimised. Double-tap the back.")
```

- [ ] **Step 3: Build**

Build `ReplrKeyboard` (⌘B). Confirm no errors.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "fix: collapsed bar — chevron.up, pill handle, whole-card tap, double-tap copy"
```

---

## Task 6: Idle state instructional card + double-tap copy (Issue 6)

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

Replace the full-width "Capture this chat" button with an instructional card that explains the capture flow and includes a small inline "Start capture ↓" action.

- [ ] **Step 1: Replace `chatContent` with instructional card**

Open `ReplrKeyboard/Views/IdlePanelView.swift`. Find the `chatContent` computed property and replace it entirely:

```swift
// MARK: - Chat idle

private var chatContent: some View {
    VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
            // Top: how-to explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("HOW TO CAPTURE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .tracking(0.8)

                Text("Open the chat, then collapse this keyboard — Replr records what's on screen when you double-tap.")
                    .font(.system(size: 13))
                    .foregroundColor(ReplrTheme.Color.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text("✦")
                        .font(.system(size: 10))
                        .foregroundColor(ReplrTheme.Color.accent)
                    Text("Anything you've typed is sent as context automatically")
                        .font(.system(size: 11.5))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                }
            }
            .padding(14)

            ReplrTheme.Color.border.frame(height: 0.5)

            // Bottom: prompt + small action button
            HStack {
                Text("Ready? Collapse to start")
                    .font(.system(size: 12))
                    .foregroundColor(ReplrTheme.Color.textSecondary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
                } label: {
                    Text("Start capture ↓")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReplrTheme.Color.onAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(ReplrTheme.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .stroke(ReplrTheme.Color.border, lineWidth: 1)
        )
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```

- [ ] **Step 2: Build**

Build `ReplrKeyboard` (⌘B). Confirm no errors.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "feat: replace idle Capture button with instructional card; double-tap copy"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| Issue 1: synchronize before reading currentContactID in viewWillAppear and poll | Task 1 Steps 2–3 |
| Issue 2: carousel fixed 88pt; keyboard height 270/275pt | Task 2 Steps 1–2 |
| Issue 3: ↺ moved to header; removed from tone strip; ReplrMark added | Task 3 Steps 1–2 |
| Issue 4: view.backgroundColor = .clear; .regularMaterial root; CollapsedStripView clear | Task 4 Steps 1–3 |
| Issue 5: pill handle, chevron.up, whole-card tap, dismiss coachmark on tap | Task 5 Step 1 |
| Issue 5: coachmark copy double-tap | Task 5 Step 2 |
| Issue 6: instructional card with Start capture ↓; double-tap body copy | Task 6 Step 1 |
| Issue 6: idle helper text updated (triple→double) | Task 6 Step 1 — card copy uses "double-tap" throughout ✓ |

**Placeholder scan:** No TBD/TODO. All steps include complete code.

**Type consistency:**
- `model.regenerate()` — defined on `KeyboardModel` ✓
- `model.isCollapsed` — `@Published var isCollapsed: Bool` on `KeyboardModel` ✓
- `ReplrTheme.Color.*`, `ReplrTheme.Radius.*`, `ReplrTheme.Motion.coachmark` — all used consistently with existing code ✓
- `ReplrMark(size: 14)` — matches usage in `KeyboardHeader` ✓
- `TapGlyph()`, `CoachmarkBalloon()`, `dismissCoachmark()` — all defined in same file ✓
- `Constants.coachmarkSeenKey`, `Constants.appGroupID` — referenced via `coachmarkKey = Constants.coachmarkSeenKey` already on the struct ✓
