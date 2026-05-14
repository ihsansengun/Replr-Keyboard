# Keyboard UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current generic keyboard UI with the black + amber Precision Tool design: B2 idle steps, skeleton loading, dark swipe-cards, persistent replies with a settings toggle.

**Architecture:** All visual changes live in `KeyboardView.swift` (color tokens + rebuilt state views). `KeyboardViewController.swift` gets 3-height logic and reply-restore on appear. `AppGroupService` + `Constants` get reply-persistence primitives. `SettingsView` gets the toggle.

**Tech Stack:** SwiftUI, UIKit (UIInputViewController), App Group UserDefaults

---

## File Map

| File | Change |
|---|---|
| `ReplrKeyboard/Views/KeyboardView.swift` | Add color tokens; rebuild IdleStateView, LoadingStateView, ReplyCarousel, ReplyCard, TonePill, toneBar |
| `ReplrKeyboard/KeyboardViewController.swift` | 3-height logic; restore cached replies on viewWillAppear; remove auto-dismiss after Use |
| `Shared/Constants.swift` | Add `persistRepliesKey`, `cachedRepliesKey` |
| `Shared/AppGroupService.swift` | Add `persistReplies`, `saveCachedReplies`, `readCachedReplies`, `clearCachedReplies`; call `saveCachedReplies` inside `saveReplies` |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Add "Keep replies between sessions" toggle |

---

### Task 1: Color tokens

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (the `KBColors` struct, around line 228)

- [ ] **Step 1: Add static design tokens to KBColors**

Replace the existing `KBColors` struct with this (keep all existing instance properties — `alpha`, `fn`, `text`, `subtext`, `shadow`, `bg` — and add the static tokens below them):

```swift
struct KBColors {
    let alpha: Color
    let fn: Color
    let text: Color
    let subtext: Color
    let shadow: Color
    let bg: Color

    static func from(_ cs: ColorScheme) -> KBColors {
        cs == .dark
        ? KBColors(
            alpha:   Color(white: 0.33),
            fn:      Color(white: 0.22),
            text:    .white,
            subtext: Color(white: 0.65),
            shadow:  .clear,
            bg:      Color(white: 0.19)
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
    static let kbBackground   = Color(red: 0.067, green: 0.067, blue: 0.067) // #111
    static let kbDeep         = Color(red: 0.051, green: 0.051, blue: 0.051) // #0D0D0D
    static let surface        = Color(red: 0.086, green: 0.086, blue: 0.086) // #161616
    static let surfaceActive  = Color(red: 0.102, green: 0.086, blue: 0.000) // #1A1600
    static let borderHair     = Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E
    static let borderDim      = Color(red: 0.165, green: 0.165, blue: 0.165) // #2A2A2A
    static let amber          = Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623
    static let amberText      = Color(red: 0.784, green: 0.627, blue: 0.376) // #C8A060
    static let amberSubtle    = Color(red: 0.353, green: 0.282, blue: 0.125) // #5A4820
    static let amberBg        = Color(red: 0.165, green: 0.125, blue: 0.000) // #2A2000
    static let amberBgBorder  = Color(red: 0.227, green: 0.188, blue: 0.063) // #3A3010
    static let textPrimary    = Color(red: 0.878, green: 0.878, blue: 0.878) // #E0E0E0
    static let textDim        = Color(red: 0.333, green: 0.333, blue: 0.333) // #555555
    static let textGhost      = Color(red: 0.165, green: 0.165, blue: 0.165) // #2A2A2A
}
```

- [ ] **Step 2: Build and confirm no errors**

Open the project in Xcode, build the ReplrKeyboard target. Expected: builds clean (no token is used yet).

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: add KBColors design tokens for UI redesign"
```

---

### Task 2: Overall background + tone bar

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (`KeyboardRootView.body`, `toneBar`, `TonePill`)

- [ ] **Step 1: Update KeyboardRootView background**

In `KeyboardRootView.body`, change:
```swift
.background(Color(UIColor.systemGroupedBackground))
```
to:
```swift
.background(KBColors.kbBackground)
```

- [ ] **Step 2: Replace TonePill**

Replace the existing `TonePill` struct with:

```swift
struct TonePill: View {
    let name: String; let isSelected: Bool; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(red: 0.067, green: 0.067, blue: 0.067) : KBColors.textDim)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(isSelected ? KBColors.amber : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }
}
```

- [ ] **Step 3: Update toneBar background and height**

In `KeyboardRootView.toneBar`, change the `.frame(height: 44)` and background:

```swift
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
                             isSelected: tone.id == model.selectedTone.id,
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
        KBColors.kbDeep
            .overlay(alignment: .top) {
                KBColors.borderHair.frame(height: 1)
            }
    )
    .animation(.easeInOut(duration: 0.18), value: stateTag)
}
```

- [ ] **Step 4: Build and verify on simulator**

Build and run on an iPhone simulator. Open any text field to trigger the keyboard. Verify:
- Keyboard body is near-black (#111)
- Tone bar is darker (#0D0D0D) with a hairline top border
- Active tone pill is amber with black text
- Inactive tones are grey text only, no background

- [ ] **Step 5: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: apply black+amber color scheme to keyboard background and tone bar"
```

---

### Task 3: Idle state (B2 step rows)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (`IdleStateView`, add `StepRow`)

- [ ] **Step 1: Add StepRow component**

After the `DoneKey` struct (around line 596), add:

```swift
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
```

- [ ] **Step 2: Replace IdleStateView**

Replace the existing `IdleStateView` struct with:

```swift
struct IdleStateView: View {
    @ObservedObject var model: KeyboardModel

    private var contextIsSet: Bool { !model.pendingContext.isEmpty }

    var body: some View {
        VStack(spacing: 5) {
            // Row 1 — Context (always active amber)
            StepRow(number: "1", isActive: true, label: "Context") {
                if contextIsSet {
                    contextChip
                } else {
                    addHintButton
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.enterContextCapture() }

            // Row 2 — Tone (activates once context is set)
            StepRow(number: "2", isActive: contextIsSet, label: "Pick a tone below") {
                EmptyView()
            }

            // Row 3 — Triple-tap (static instruction)
            StepRow(number: "3", isActive: false, label: "Triple-tap back of phone") {
                EmptyView()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.18), value: contextIsSet)
    }

    private var contextChip: some View {
        HStack(spacing: 4) {
            Text(model.pendingContext)
                .font(.system(size: 11))
                .foregroundColor(KBColors.amberText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)
            Button {
                model.clearContext()
            } label: {
                Text("✕")
                    .font(.system(size: 9))
                    .foregroundColor(KBColors.amberSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 7).padding(.trailing, 5).padding(.vertical, 2)
        .background(KBColors.amberBg)
        .overlay(
            Capsule().stroke(KBColors.amberBgBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var addHintButton: some View {
        Text("+ Add hint…")
            .font(.system(size: 11))
            .foregroundColor(KBColors.amberSubtle)
    }
}
```

- [ ] **Step 3: Build and verify**

Build and run. Open the keyboard in idle state. Verify:
- Three rows visible with amber left bars on active rows
- Row 1 always amber; "Triple-tap" row always dimmed
- "+ Add hint…" appears on the right of row 1 when no context is set
- Tapping row 1 opens the context capture keyboard
- After saving context, amber chip appears with ✕, row 2 activates

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: redesign idle state with B2 step rows and context chip"
```

---

### Task 4: Loading state (skeleton card)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (`LoadingStateView`, add `SkeletonLine`)

- [ ] **Step 1: Replace LoadingStateView**

Replace the existing `LoadingStateView` struct with:

```swift
struct LoadingStateView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            // Skeleton card matching reply card shape
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(fraction: 1.0, pulse: pulse)
                SkeletonLine(fraction: 0.75, pulse: pulse)
                SkeletonLine(fraction: 0.5, pulse: pulse)
                Spacer().frame(height: 4)
                HStack {
                    SkeletonLine(fraction: 0.35, pulse: pulse)
                    Spacer()
                    SkeletonLine(fraction: 0.18, pulse: pulse).frame(maxWidth: 50)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .background(KBColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Amber dot (first, others grey — matches reply dots)
            HStack(spacing: 5) {
                Circle().fill(KBColors.amber).frame(width: 5, height: 5)
                Circle().fill(KBColors.surface).frame(width: 5, height: 5)
                Circle().fill(KBColors.surface).frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct SkeletonLine: View {
    let fraction: CGFloat  // 0.0–1.0 relative to container width
    let pulse: Bool

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(white: pulse ? 0.18 : 0.13))
                .frame(width: geo.size.width * fraction, height: 10)
        }
        .frame(height: 10)
    }
}
```

- [ ] **Step 2: Build and verify**

Temporarily force `model.state = .loading` in `KeyboardViewController.viewWillAppear` to test, then revert. Verify:
- Three skeleton lines visible with a shorter footer row
- Lines pulse between two shades of dark grey
- Amber dot at the top of the dot indicator

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: redesign loading state with skeleton card and pulse animation"
```

---

### Task 5: Reply state (dark cards, amber accents)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (`ReplyCarousel`, `PageDots`, `ReplyCard`, `ReplyCardButtonStyle`)

- [ ] **Step 1: Replace ReplyCarousel**

Replace the existing `ReplyCarousel` struct with:

```swift
struct ReplyCarousel: View {
    let replies: [String]
    let onSelect: (String) -> Void
    let onEdit: (String) -> Void
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 6) {
            // Card stack — back card peeks behind front card
            ZStack(alignment: .bottomTrailing) {
                // Back card peek (offset bottom-right)
                if replies.count > 1 {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.094))
                        .opacity(0.6)
                        .padding(.leading, 10)
                        .padding(.trailing, -3)
                        .padding(.bottom, -3)
                }

                // Paging front cards
                TabView(selection: $currentPage) {
                    ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                        ReplyCard(
                            text: reply,
                            showSwipeHint: replies.count > 1,
                            onTap: { onSelect(reply) },
                            onEdit: { onEdit(reply) }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: 130)

            // Dots indicator
            if replies.count > 1 {
                PageDots(count: replies.count, current: currentPage)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 2: Replace PageDots**

Replace the existing `PageDots` struct with:

```swift
struct PageDots: View {
    let count: Int; let current: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? KBColors.amber : KBColors.surface)
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}
```

- [ ] **Step 3: Replace ReplyCard**

Replace the existing `ReplyCard` struct with:

```swift
struct ReplyCard: View {
    let text: String
    let showSwipeHint: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Main tap target — full card
            Button(action: onTap) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(KBColors.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
                    .padding(.top, 13)
                    .padding(.bottom, 32)
            }
            .buttonStyle(ReplyCardButtonStyle())

            // Footer row: swipe hint + Edit button
            HStack(spacing: 0) {
                if showSwipeHint {
                    Text("← swipe")
                        .font(.system(size: 10))
                        .foregroundColor(KBColors.textGhost)
                }
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
```

- [ ] **Step 4: Update ReplyCardButtonStyle**

The existing `ReplyCardButtonStyle` is fine — keep it unchanged.

- [ ] **Step 5: Update KeyboardRootView to pass onEdit correctly**

In `KeyboardRootView.contentArea`, the `ReplyCarousel` call already has `onEdit: { model.enterEditReply($0) }` — verify this is present and unchanged:

```swift
case .replies(let replies):
    ReplyCarousel(replies: replies,
                  onSelect: { model.selectReply($0) },
                  onEdit: { model.enterEditReply($0) })
        .transition(.opacity)
```

- [ ] **Step 6: Build and verify**

Trigger a reply generation on device/simulator. Verify:
- Reply card is dark (#161616 surface), text is light (#E0E0E0)
- Back card peeks from behind the front card (darker, offset)
- Dots at bottom: amber for current, dark grey for others
- "Edit" button is amber
- Swipe hint "← swipe" shows when more than one reply

- [ ] **Step 7: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: redesign reply cards with dark surface, amber accents, back-card peek"
```

---

### Task 6: Three-height logic

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift` (the `stateCancellable` sink, line 38–52)

- [ ] **Step 1: Update height mapping**

Replace the `stateCancellable` sink body with:

```swift
stateCancellable = model.$state
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        guard let self else { return }
        let newHeight: CGFloat
        switch state {
        case .contextCapture, .editReply: newHeight = 248  // keyboard active
        case .loading, .replies:          newHeight = 320  // reply/loading area needs room
        default:                          newHeight = 250  // idle, error
        }
        if self.heightConstraint.constant != newHeight {
            self.heightConstraint.constant = newHeight
            UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
        }
    }
```

Also update the initial height on line 14 from `260` to `250`:

```swift
heightConstraint = view.heightAnchor.constraint(equalToConstant: 250)
```

- [ ] **Step 2: Build and verify**

Run on simulator. Open keyboard (250px). Triple-tap to generate. Verify keyboard grows to 320px when loading/replies appear. Switch to context capture — keyboard shrinks to 248px to accommodate QWERTY.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: three-height keyboard: 250 idle, 320 reply/loading, 248 keyboard active"
```

---

### Task 7: Stay on reply after Use

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift` (`insert` method, line 101–106)

- [ ] **Step 1: Remove auto-dismiss from insert**

Replace the existing `insert` method:

```swift
private func insert(_ text: String) {
    textDocumentProxy.insertText(text)
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
```

The `DispatchQueue.main.asyncAfter` + `advanceToNextInputMode()` call is removed. The text is inserted, haptic fires, and the keyboard stays in reply state so the user can pick another reply or dismiss manually.

- [ ] **Step 2: Verify**

On simulator: generate replies, tap "Use" on a card. Verify text is inserted into the text field AND the keyboard stays on the reply state (does not switch back to native keyboard).

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: stay on reply state after tapping Use — user dismisses manually"
```

---

### Task 8: Reply persistence

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Add keys to Constants**

In `Constants.swift`, add two keys inside the `enum`:

```swift
static let persistRepliesKey  = "persist_replies"
static let cachedRepliesKey   = "cached_replies"
```

- [ ] **Step 2: Add persistence methods to AppGroupService**

Add the following methods to `AppGroupService`, after the `consumeError` block:

```swift
// MARK: - Reply persistence (restore on keyboard reopen)

var persistReplies: Bool {
    get { defaults.object(forKey: Constants.persistRepliesKey) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Constants.persistRepliesKey); defaults.synchronize() }
}

func saveCachedReplies(_ replies: [String]) {
    guard let data = try? JSONEncoder().encode(replies) else { return }
    defaults.set(data, forKey: Constants.cachedRepliesKey)
    defaults.synchronize()
}

func readCachedReplies() -> [String]? {
    defaults.synchronize()
    guard let data = defaults.data(forKey: Constants.cachedRepliesKey),
          let replies = try? JSONDecoder().decode([String].self, from: data),
          !replies.isEmpty else { return nil }
    return replies
}

func clearCachedReplies() {
    defaults.removeObject(forKey: Constants.cachedRepliesKey)
    defaults.synchronize()
}
```

- [ ] **Step 3: Call saveCachedReplies inside saveReplies**

In `AppGroupService.saveReplies`, add one line after `defaults.set(true, forKey: Constants.hasNewRepliesKey)`:

```swift
func saveReplies(_ replies: [String]) {
    NSLog("[Replr][AppGroup] saveReplies count=%d", replies.count)
    guard let data = try? JSONEncoder().encode(replies) else { return }
    defaults.set(data, forKey: Constants.pendingRepliesKey)
    defaults.set(true, forKey: Constants.hasNewRepliesKey)
    saveCachedReplies(replies)          // <-- add this line
    defaults.synchronize()
    NSLog("[Replr][AppGroup] saveReplies: wrote to UserDefaults + synchronize()")
}
```

- [ ] **Step 4: Clear cache when user taps New (regenerate)**

In `KeyboardModel.regenerate()`, add the cache clear:

```swift
func regenerate() {
    AppGroupService.shared.clearCachedReplies()
    withAnimation(.easeInOut(duration: 0.2)) { state = .idle }
}
```

- [ ] **Step 5: Restore cached replies on keyboard appear**

In `KeyboardViewController.viewWillAppear`, add the restore block after `model.pendingContext` is set:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.needsGlobeKey = needsInputModeSwitchKey
    model.pendingContext = AppGroupService.shared.readPendingContext() ?? ""

    // Restore last replies if persist is enabled
    if AppGroupService.shared.persistReplies,
       let cached = AppGroupService.shared.readCachedReplies() {
        model.currentReplies = cached
        model.state = .replies(cached)
    }

    startCapturePoll()
}
```

- [ ] **Step 6: Build and verify**

Generate replies on simulator. Close the keyboard by tapping outside. Reopen it (tap the text field again). Verify replies are still shown. Then tap "New" (the ↺ regenerate button in the tone bar) — keyboard returns to idle. Close and reopen — verify idle state this time (cache was cleared).

- [ ] **Step 7: Commit**

```bash
git add Shared/Constants.swift Shared/AppGroupService.swift ReplrKeyboard/KeyboardViewController.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: persist last replies between sessions, clear on New"
```

---

### Task 9: Settings toggle

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add Keyboard section with persistReplies toggle**

Replace the entire `SettingsView` with:

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredModel") var preferredModel = "claude"
    @State private var persistReplies = AppGroupService.shared.persistReplies

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Model") {
                    Picker("Model", selection: $preferredModel) {
                        Text("Claude (Anthropic)").tag("claude")
                        Text("GPT-4o (OpenAI)").tag("gpt4o")
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle("Keep replies between sessions", isOn: $persistReplies)
                        .onChange(of: persistReplies) { _, newValue in
                            AppGroupService.shared.persistReplies = newValue
                        }
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("When enabled, your last generated replies stay visible the next time you open the keyboard.")
                }

                Section("Account") {
                    NavigationLink("Subscription") { SubscriptionView() }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run the main Replr app. Navigate to Settings. Verify:
- "Keyboard" section appears with the toggle
- Toggle is on by default
- Toggling off and returning persists the setting (close app, reopen — toggle stays off)
- When off: closing and reopening the keyboard opens to idle state

- [ ] **Step 3: Commit**

```bash
git add Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "feat: add persist replies toggle to Settings"
```

---

### Task 10: Error state styling

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (`ErrorStateView`)

- [ ] **Step 1: Update ErrorStateView**

Replace the existing `ErrorStateView` struct with:

```swift
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
```

No icon — matches spec (simple inline text only). The `contentShape` ensures tapping anywhere in the error area works if needed in future.

- [ ] **Step 2: Build and verify**

Temporarily force an error state: in `KeyboardViewController.viewWillAppear`, add `model.state = .error("No connection. Check your internet and try again.")` for testing, then revert after verifying. Check the error text is dim grey, centered, no icon.

- [ ] **Step 3: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: simplified error state — text only, no icon"
```

---

### Task 11: Final integration check

- [ ] **Step 1: Full flow test on device or simulator**

Run on a real device or simulator. Go through the complete flow:
1. Open keyboard → see B2 idle state (3 dark rows, amber row 1)
2. Tap row 1 → context keyboard appears → type "Free next week" → Save → chip appears, row 2 activates
3. Tap a tone in the tone bar → verify amber pill selection
4. Triple-tap back of phone → keyboard shows skeleton card (loading)
5. Replies arrive → swipe card with back-card peek, amber dots, amber Edit
6. Tap "Use" → text inserted, keyboard stays on reply state
7. Tap ↺ in tone bar → back to idle
8. Close and reopen keyboard → replies still shown (persist enabled)
9. In main app Settings → toggle off persist → close/reopen keyboard → opens to idle

- [ ] **Step 2: Check for regressions**

- Context capture flow still works (type → Save → chip)
- Edit flow still works (Edit button → edit keyboard → Send → back to replies)
- Email tone still works (copy email text → triple-tap → clipboard path)
- Tone switching works in all states

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: keyboard UI redesign complete — black+amber, B2 idle, skeleton loading, dark cards"
git push origin main
```
