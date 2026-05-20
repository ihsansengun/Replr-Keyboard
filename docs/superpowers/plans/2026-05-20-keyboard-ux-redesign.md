# Keyboard UX Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `ReplrStrip` with a full-width labeled segmented control (Chat/Email) + scrollable tone row, rebuild every keyboard state panel to the new spec, and fix screenshot capture so the keyboard collapses to 0px height before the photo is taken.

**Architecture:** A new `KeyboardHeader` component (composes `ModeSegmentedControl` + `ToneRow`) is used in every state panel. Each state gets its own file. `KeyboardViewController` uses `combineLatest(model.$state, model.$isCaptureMode)` for height management, animating to 0px in 0.15s when capture is in flight, then back to the appropriate height when replies arrive.

**Tech Stack:** SwiftUI, UIKit (`UIInputViewController`), Combine, SF Symbols

**Build command (run after every task):**
```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```
Expected: `** BUILD SUCCEEDED **`

---

## File Map

| File | Action |
|------|--------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Add `isCaptureMode` to model; add `ModeSegmentedControl`, `ToneRow`, `KeyboardHeader`; update `TonePill` inactive bg; update `SkeletonLine` shimmer colors; rewrite `KeyboardRootView` to use panels; remove `ReplrStrip`, `ChatIcon`, `EmailIcon`, `DisambiguateView` |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Full rewrite — chat (capture zone + draft row) and email (clipboard button) using `KeyboardHeader` |
| `ReplrKeyboard/Views/LoadingPanelView.swift` | New — spinner label + skeleton lines + `KeyboardHeader` |
| `ReplrKeyboard/Views/ErrorPanelView.swift` | New — error icon + message + retry + `KeyboardHeader` |
| `ReplrKeyboard/Views/ReplyListView.swift` | Update `ReplyListView` + `ReplyRowView` — add `isSent`/`isDimmed`/`onUndo`, send button morphs to outlined ↩ on sent card |
| `ReplrKeyboard/Views/RepliesPanelView.swift` | New — `KeyboardHeader` + contact chip row + `ReplyListView` |
| `ReplrKeyboard/Views/DisambiguatePanelView.swift` | New — dimmed disabled segmented header (no tone row) + `DisambiguateView` (moved from `KeyboardView.swift`) |
| `ReplrKeyboard/KeyboardViewController.swift` | Add `isCaptureMode` sink; `combineLatest` height management; new heights (idle=270, loading=200, error=200, disambiguate=300, replies=max(200,min(340,100+N×52)), capture=0); poll loop sets `isCaptureMode=true` instead of `advanceToNextInputMode()` |

---

## Task 1: Foundation — Model + Colors + Header Components

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Add `isCaptureMode` to `KeyboardModel` and 3 new `KBColors` entries**

In `KeyboardView.swift`, add `@Published var isCaptureMode: Bool = false` to `KeyboardModel` (after the `inputMode` line), and add three color constants to the `KBColors` struct:

```swift
// in KeyboardModel, after `@Published var inputMode: KeyboardInputMode = .chat`
@Published var isCaptureMode: Bool = false
```

```swift
// in KBColors, after `static let textGhost`
static let segmentedBg = Color(red: 0.165, green: 0.125, blue: 0.063) // #2a2010
static let sentCard    = Color(red: 0.102, green: 0.102, blue: 0.063) // #1a1a10
static let undoBtnBg   = Color(red: 0.227, green: 0.165, blue: 0.000) // #3a2a00
```

- [ ] **Step 2: Update `TonePill` — inactive background**

Change the inactive pill background from `Color.clear` to `KBColors.surface` so inactive pills have the `#241E13` fill from the spec:

```swift
// Replace the .background line in TonePill.body:
.background(isSelected ? KBColors.accent : KBColors.surface)
```

- [ ] **Step 3: Update `SkeletonLine` — spec colors + shimmer**

Replace the `SkeletonLine` struct body with shimmer colors from the spec (`#2a2010` base, `#3a3018` highlight):

```swift
struct SkeletonLine: View {
    let fraction: CGFloat
    let pulse: Bool
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.165, green: 0.125, blue: 0.063), location: 0),
                        .init(color: Color(red: 0.227, green: 0.188, blue: 0.094), location: shimmer ? 0.5 : 0.15),
                        .init(color: Color(red: 0.165, green: 0.125, blue: 0.063), location: 1),
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
```

- [ ] **Step 4: Add `ModeSegmentedControl` struct to `KeyboardView.swift`**

Insert this after the `KBColors` struct:

```swift
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
```

- [ ] **Step 5: Add `ToneRow` struct to `KeyboardView.swift`**

Insert after `ModeSegmentedControl`:

```swift
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
```

- [ ] **Step 6: Add `KeyboardHeader` struct to `KeyboardView.swift`**

Insert after `ToneRow`:

```swift
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
```

- [ ] **Step 7: Build to verify compilation**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add ModeSegmentedControl, ToneRow, KeyboardHeader; isCaptureMode on model

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Rewrite `IdlePanelView.swift`

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] **Step 1: Replace the entire file**

```swift
import SwiftUI

struct IdlePanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            if model.inputMode == .chat {
                chatContent
            } else {
                emailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.background)
    }

    // MARK: - Chat idle

    private var chatContent: some View {
        VStack(spacing: 0) {
            CaptureZoneView()
                .padding(8)
            if !model.pendingContext.isEmpty {
                draftRow
            }
            Spacer(minLength: 0)
        }
    }

    private var draftRow: some View {
        Text(model.pendingContext)
            .font(.system(size: 9))
            .foregroundColor(KBColors.textDim)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(KBColors.deep)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(KBColors.borderHair, lineWidth: 0.5)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 6) {
            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16))
                    Text("↑ Generate from clipboard")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(8)

            Text("Copy the email text first, then tap above")
                .font(.system(size: 10))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Capture Zone

private struct CaptureZoneView: View {
    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                rippleCircle(expanding: $ring1)
                rippleCircle(expanding: $ring2)
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(KBColors.accent)
            }
            .frame(height: 54)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    ring1 = true
                }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(0.55)) {
                    ring2 = true
                }
            }

            Text("Back Tap to capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KBColors.accent)
            Text("screenshot → AI replies")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rippleCircle(expanding: Binding<Bool>) -> some View {
        Circle()
            .stroke(KBColors.accent.opacity(0.75), lineWidth: 1.5)
            .frame(width: expanding.wrappedValue ? 44 : 6,
                   height: expanding.wrappedValue ? 44 : 6)
            .opacity(expanding.wrappedValue ? 0 : 1)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "$(cat <<'EOF'
feat: rewrite IdlePanelView — chat capture zone + email clipboard button with KeyboardHeader

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Create `LoadingPanelView.swift`

**Files:**
- Create: `ReplrKeyboard/Views/LoadingPanelView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct LoadingPanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isToneDimmed: true)
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.55)
                        .tint(KBColors.accent)
                    Text("Generating replies…")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.accent.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    SkeletonLine(fraction: 0.80, pulse: false)
                    SkeletonLine(fraction: 0.95, pulse: true)
                    SkeletonLine(fraction: 0.65, pulse: false)
                }
                .padding(.horizontal, 12)
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.background)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/LoadingPanelView.swift
git commit -m "$(cat <<'EOF'
feat: add LoadingPanelView — spinner label + skeleton shimmer lines

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Create `ErrorPanelView.swift`

**Files:**
- Create: `ReplrKeyboard/Views/ErrorPanelView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct ErrorPanelView: View {
    let message: String
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            errorContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.background)
    }

    private var errorContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(KBColors.accent.opacity(0.8))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)

            Button { model.retryGeneration() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(KBColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(KBColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(KBColors.borderHair, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/ErrorPanelView.swift
git commit -m "$(cat <<'EOF'
feat: add ErrorPanelView — warning icon + message + retry button

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update `ReplyListView.swift` — sent card / undo in-place

**Files:**
- Modify: `ReplrKeyboard/Views/ReplyListView.swift`

The send button morphs to an outlined ↩ undo button in-place on the sent card. Other cards dim to 0.35 opacity. `Edit` button is hidden on the sent card.

- [ ] **Step 1: Replace the entire file**

```swift
import SwiftUI

struct ReplyListView: View {
    let replies: [String]
    let lastInsertedReply: String?
    let onSend: (String) -> Void
    let onEdit: (String) -> Void
    let onUndo: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                    ReplyRowView(
                        text: reply,
                        isSent: reply == lastInsertedReply,
                        isDimmed: lastInsertedReply != nil && reply != lastInsertedReply,
                        onSend: { onSend(reply) },
                        onEdit: { onEdit(reply) },
                        onUndo: onUndo
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
    let isSent: Bool
    let isDimmed: Bool
    let onSend: () -> Void
    let onEdit: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isSent ? KBColors.textDim : KBColors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isSent {
                Button("Edit", action: onEdit)
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KBColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .buttonStyle(.plain)
            }

            if isSent {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KBColors.accent)
                        .frame(width: 28, height: 28)
                        .background(KBColors.undoBtnBg)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(KBColors.accent, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo send")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KBColors.accentFg)
                        .frame(width: 28, height: 28)
                        .background(KBColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send reply")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSent ? KBColors.sentCard : KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSent ? KBColors.accent.opacity(0.18) : KBColors.borderHair,
                    lineWidth: isSent ? 1.0 : 0.5
                )
        )
        .opacity(isDimmed ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSent)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
    }
}
```

- [ ] **Step 2: Build to verify** (will fail until Task 6 updates the caller — that's expected)

Note: `RepliesPanelView` doesn't exist yet, so `KeyboardRootView` still uses the old `repliesPanel` helper which calls `ReplyListView` without the new params. The build will still succeed because the old inline `repliesPanel` in `KeyboardRootView` will now have a type error. Fix it temporarily by updating the inline call in `KeyboardRootView.repliesPanel` to pass the new params:

In `KeyboardView.swift`, find `private func repliesPanel(_ replies: [String]) -> some View` and update the `ReplyListView(...)` call:

```swift
ReplyListView(
    replies: replies,
    lastInsertedReply: model.lastInsertedReply,
    onSend: { model.selectReply($0) },
    onEdit: { model.editReply($0) },
    onUndo: { model.onUndoInsert?() }
)
```

Then build:

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/ReplyListView.swift \
        Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: ReplyRowView send button morphs to undo in-place on sent card

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Create `RepliesPanelView.swift`

**Files:**
- Create: `ReplrKeyboard/Views/RepliesPanelView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model)
            if let name = model.contactName {
                contactChipRow(name)
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
        .background(KBColors.background)
    }

    private func contactChipRow(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .foregroundColor(KBColors.accent)
            .padding(.leading, 14)

            Spacer()

            Button { model.regenerate() } label: {
                Text("↺ New replies")
                    .font(.system(size: 10))
                    .foregroundColor(KBColors.textDim)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .frame(height: 26)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "$(cat <<'EOF'
feat: add RepliesPanelView — contact chip + new-replies link + ReplyListView

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Create `DisambiguatePanelView.swift` and move `DisambiguateView`

**Files:**
- Create: `ReplrKeyboard/Views/DisambiguatePanelView.swift`
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` (remove `DisambiguateView`)

- [ ] **Step 1: Create `DisambiguatePanelView.swift`**

Move the `DisambiguateView` struct (lines 327–433 in `KeyboardView.swift`) into this new file, then add the panel wrapper:

```swift
import SwiftUI

// MARK: - Disambiguate Panel

struct DisambiguatePanelView: View {
    @ObservedObject var model: KeyboardModel
    let name: String
    let candidates: [Contact]

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isSegmentedDisabled: true, isToneHidden: true)
            DisambiguateView(
                name: name,
                candidates: candidates,
                onSelectContact: { model.onSelectContact?($0) },
                onCreateNew: { model.onCreateNewContact?($0) }
            )
        }
        .background(KBColors.background)
    }
}

// MARK: - Disambiguate View (contact picker list)

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
```

- [ ] **Step 2: Remove `DisambiguateView` from `KeyboardView.swift`**

Delete the entire `// MARK: - Disambiguate View` section and the `DisambiguateView` struct (approximately lines 327–433 in the current file).

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/DisambiguatePanelView.swift \
        Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add DisambiguatePanelView — dimmed header, no tone row; move DisambiguateView

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Rewrite `KeyboardRootView` — wire all panels, remove `ReplrStrip`

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Replace `KeyboardRootView` with the new panel-switched version**

Find the `// MARK: - Root View` section and replace the entire `KeyboardRootView` struct with:

```swift
// MARK: - Root View

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        ZStack {
            switch model.state {
            case .idle:
                IdlePanelView(model: model).transition(.opacity)
            case .loading:
                LoadingPanelView(model: model).transition(.opacity)
            case .replies(let replies):
                RepliesPanelView(model: model, replies: replies).transition(.opacity)
            case .error(let message):
                ErrorPanelView(message: message, model: model).transition(.opacity)
            case .disambiguate(let name, let candidates):
                DisambiguatePanelView(model: model, name: name, candidates: candidates)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stateTag)
        .background(KBColors.background)
        .ignoresSafeArea()
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

- [ ] **Step 2: Remove `ReplrStrip`, `ChatIcon`, `EmailIcon` from `KeyboardView.swift`**

Delete:
- The `// MARK: - Custom Mode Icons` section with `ChatIcon` and `EmailIcon` structs (lines 6–54)
- The `// MARK: - Replr Strip` section with the entire `ReplrStrip` struct (lines 437–651)

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: KeyboardRootView wires all new panels; remove ReplrStrip, ChatIcon, EmailIcon

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update `KeyboardViewController.swift` — `isCaptureMode` + new heights

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Update initial height constraint**

Change the initial `heightConstraint` constant from `316` to `270` (new idle height):

```swift
// line 16 — change 316 → 270
heightConstraint = view.heightAnchor.constraint(equalToConstant: 270)
```

- [ ] **Step 2: Replace the `stateCancellable` sink with `combineLatest`**

Replace the existing `stateCancellable = model.$state.receive(on:).sink { ... }` block (lines 76–91) with:

```swift
stateCancellable = model.$state
    .combineLatest(model.$isCaptureMode)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state, isCaptureMode in
        guard let self else { return }
        if isCaptureMode {
            self.setHeight(0, duration: 0.15)
            return
        }
        let height: CGFloat
        switch state {
        case .idle:         height = 270
        case .loading:      height = 200
        case .error:        height = 200
        case .disambiguate: height = 300
        case .replies(let replies):
            height = max(200, min(340, 100 + CGFloat(replies.count) * 52))
        }
        self.setHeight(height)
    }
```

- [ ] **Step 3: Update `setHeight` to accept a duration parameter**

Replace the existing `setHeight` method (lines 229–233) with:

```swift
private func setHeight(_ height: CGFloat, duration: TimeInterval = 0.25) {
    guard heightConstraint.constant != height else { return }
    heightConstraint.constant = height
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
}
```

- [ ] **Step 4: Update the poll loop — collapse to 0px instead of switching keyboard**

In `startCapturePoll()`, replace the `switchKeyboardRequested` branch:

```swift
// Old:
if AppGroupService.shared.switchKeyboardRequested {
    AppGroupService.shared.setSwitchKeyboardRequested(false)
    await MainActor.run { self.advanceToNextInputMode() }
}

// New:
if AppGroupService.shared.switchKeyboardRequested {
    AppGroupService.shared.setSwitchKeyboardRequested(false)
    await MainActor.run { self.model.isCaptureMode = true }
}
```

- [ ] **Step 5: Clear `isCaptureMode` when replies arrive**

In the `consumeReplies()` branch inside the poll loop, add `self.model.isCaptureMode = false` before setting state:

```swift
} else if let replies = AppGroupService.shared.consumeReplies() {
    NSLog("[Replr][Keyboard] poll: %d replies", replies.count)
    AppGroupService.shared.savePendingContext("")
    await MainActor.run {
        self.model.isCaptureMode = false          // ← add this line
        self.model.currentReplies = replies
        if let id = AppGroupService.shared.currentContactID,
           let contact = AppGroupService.shared.loadContacts().first(where: { $0.id == id }) {
            self.model.contactName = contact.displayName
        } else {
            self.model.contactName = nil
        }
        self.model.hasAnySessions = true
        withAnimation(.easeInOut(duration: 0.2)) {
            self.model.state = .replies(replies)
        }
    }
```

Also clear `isCaptureMode` when an error arrives (so the keyboard doesn't stay invisible):

```swift
} else if let error = AppGroupService.shared.consumeError() {
    NSLog("[Replr][Keyboard] poll error: %@", error)
    await MainActor.run {
        self.model.isCaptureMode = false           // ← add this line
        withAnimation { self.model.state = .error(error) }
    }
}
```

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -target ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/KeyboardViewController.swift
git commit -m "$(cat <<'EOF'
feat: collapse keyboard to 0px for capture; combineLatest height sink; new state heights

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Heights Summary

| State        | Height  | Formula |
|--------------|---------|---------|
| Idle         | 270px   | fixed |
| Loading      | 200px   | fixed |
| Error        | 200px   | fixed |
| Disambiguate | 300px   | fixed |
| Replies (N)  | 200–340px | max(200, min(340, 100 + N × 52)) |
| Capturing    | 0px     | isCaptureMode = true |

All height transitions: `UIView.animate(withDuration: 0.25)` except capture collapse which uses `0.15s`.

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| Segmented control — full-width, labeled, icons | Task 1 (ModeSegmentedControl) |
| Segmented control — 44px, disabled in disambiguate | Task 1 (KeyboardHeader), Task 7 |
| Tone row — 30px, globe key, dimmed 0.35 in loading | Task 1 (ToneRow) |
| Inactive tone pill surface bg `#241E13` | Task 1 (TonePill update) |
| Idle chat — capture zone + ripple + draft row | Task 2 |
| Idle email — clipboard button + hint | Task 2 |
| Draft row hidden when `pendingContext` is empty | Task 2 (conditional rendering) |
| Loading — spinner + skeleton shimmer | Task 3 |
| Error — warning icon + message + retry | Task 4 |
| Send button morphs to ↩ undo on sent card | Task 5 |
| Other cards dim 0.35 when one is sent | Task 5 |
| Replies — contact chip row + new-replies link | Task 6 |
| Disambiguate — dimmed segmented, no tone row | Task 7 |
| 0px collapse for capture | Task 9 |
| combineLatest height management | Task 9 |
| isCaptureMode cleared on replies/error | Task 9 |

**No placeholders present.** All steps contain complete Swift code.

**Type consistency:** `ReplyListView` now takes `lastInsertedReply: String?` and `onUndo: () -> Void` — both callers (`KeyboardRootView.repliesPanel` temp fix in Task 5, `RepliesPanelView` in Task 6) pass these. After Task 8, the temp fix in `KeyboardRootView` is replaced by `RepliesPanelView` so both paths are covered.

**One potential issue:** `TonePill` inactive background changes from `Color.clear` to `KBColors.surface`. This is a visual change that will make inactive pills have a dark fill instead of being transparent. This matches the spec and the design mockup (option A cards).
