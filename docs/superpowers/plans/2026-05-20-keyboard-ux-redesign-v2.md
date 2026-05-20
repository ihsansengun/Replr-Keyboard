# Keyboard UX Redesign v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip warm brown tint from every surface (neutral palette), de-amberize the segmented control, replace the instruction card with a wide "Capture this chat" CTA, make the capture bar explicit and cancellable, rebuild the replies screen as a full-screen carousel with wide primary button and tone strip at bottom, and give the error panel an amber "Try again" CTA.

**Architecture:** Seven focused tasks, each touching one file or a tightly coupled pair. No new architectural primitives — only rewrites and color token changes. All changes are backward compatible with `KeyboardViewController` and `KeyboardModel`; no new states or callbacks needed except `startRenameContact()` on `KeyboardModel`.

**Tech Stack:** SwiftUI, Combine, SF Symbols, `UIInputViewController`

**Build command (verify after every task):**
```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```
Expected: `** BUILD SUCCEEDED **`

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Modify | `KBColors` neutral palette; `ModeSegmentedControl` de-amberized; `CollapsedStripView` rewritten; `KeyboardModel.startRenameContact()` added |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Modify | Chat: `CaptureZoneView` replaced by wide amber "Capture this chat" button; Email: sub-line color updated |
| `ReplrKeyboard/Views/RepliesPanelView.swift` | Modify | Full rewrite — single carousel pager, contact header with ✎ + N-of-M, wide Insert primary, Edit secondary, tone strip at bottom |
| `ReplrKeyboard/Views/ReplyListView.swift` | Modify | Delete `ReplyListView`/`ReplyRowView`; keep `EmailReplyPagerView` renamed to `ReplyCarouselView` (unified for chat+email) |
| `ReplrKeyboard/Views/ErrorPanelView.swift` | Modify | Wide amber "Try again" primary replaces neutral "Retry" button |
| `ReplrKeyboard/Views/LoadingPanelView.swift` | Modify | Reply-card-shaped skeleton replaces inline skeleton lines |
| `ReplrKeyboard/KeyboardViewController.swift` | Modify | Height: replies→360 (email stays 380), loading→230, error→240 |

---

## Task 1: Neutral color palette + de-amberize ModeSegmentedControl + rewrite CollapsedStripView

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Replace `KBColors` with neutral palette**

Find the `struct KBColors` block (currently ~line 209) and replace the entire struct body:

```swift
struct KBColors {
    // MARK: - Design tokens

    // Accent — brighter amber
    static let accent        = Color(red: 0.949, green: 0.663, blue: 0.235) // #F2A93C
    static let accentFg      = Color(red: 0.227, green: 0.141, blue: 0.004) // #3A2401
    static let accentSubtle  = Color(red: 0.949, green: 0.663, blue: 0.235, opacity: 0.50)
    static let accentBg      = Color(red: 0.949, green: 0.663, blue: 0.235, opacity: 0.12)
    static let accentBgBorder = Color(red: 0.949, green: 0.663, blue: 0.235, opacity: 0.38)
    static let accentShadow  = Color(red: 0.478, green: 0.353, blue: 0.000) // #7A5A00

    // Shell backgrounds — neutral dark, no warm tint
    static let background    = Color(red: 0.059, green: 0.059, blue: 0.071) // #0F0F12
    static let deep          = Color(red: 0.082, green: 0.082, blue: 0.098) // #151519
    static let surface       = Color(red: 0.106, green: 0.106, blue: 0.125) // #1B1B20
    static let raised        = Color(red: 0.149, green: 0.149, blue: 0.173) // #26262C

    // Borders + text
    static let borderHair    = Color(red: 0.180, green: 0.180, blue: 0.212) // #2E2E36
    static let borderDim     = Color(red: 0.250, green: 0.250, blue: 0.290)
    static let textPrimary   = Color(red: 0.929, green: 0.914, blue: 0.890) // #EDE9E3
    static let textDim       = Color(red: 0.604, green: 0.588, blue: 0.557) // #9A968E
    static let textGhost     = Color(red: 0.430, green: 0.420, blue: 0.385)
    static let segmentedBg   = Color(red: 0.106, green: 0.106, blue: 0.125) // same as surface
    static let sentCard      = Color(red: 0.082, green: 0.082, blue: 0.110) // #15151C
    static let undoBtnBg     = Color(red: 0.149, green: 0.090, blue: 0.000) // #261700
    static let skeletonHighlight = Color(red: 0.200, green: 0.200, blue: 0.235) // #33333C
    static let surfaceActive = Color(red: 0.180, green: 0.180, blue: 0.212)
}
```

- [ ] **Step 2: De-amberize `ModeSegmentedControl` active state**

Find the `segmentBtn` private func inside `ModeSegmentedControl`. Change the active segment label so it uses `raised` fill and `textPrimary` text instead of amber:

```swift
// Replace the label's foreground and background lines:
.foregroundColor(isActive ? KBColors.textPrimary : KBColors.textDim)
// ...
.background(
    RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(isActive ? KBColors.raised : Color.clear)
)
```

Full replacement for the `segmentBtn` `label` closure:

```swift
} label: {
    HStack(spacing: 4) {
        Image(systemName: iconName)
            .font(.system(size: 13))
        Text(label)
            .font(.system(size: 11, weight: .semibold))
    }
    .foregroundColor(isActive ? KBColors.textPrimary : KBColors.textDim)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 5)
    .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isActive ? KBColors.raised : Color.clear)
    )
}
```

- [ ] **Step 3: Rewrite `CollapsedStripView`**

Find the `// MARK: - Collapsed Strip` section and replace the entire `CollapsedStripView` struct:

```swift
// MARK: - Collapsed Strip

struct CollapsedStripView: View {
    @ObservedObject var model: KeyboardModel
    @State private var phoneScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            // Amber left edge
            KBColors.accent
                .frame(width: 3)

            HStack(spacing: 10) {
                // Animated phone glyph
                Image(systemName: "iphone.rear.camera")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(KBColors.accent)
                    .scaleEffect(phoneScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                        ) { phoneScale = 0.82 }
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Triple-tap the back of your phone")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KBColors.textPrimary)
                    Text("to capture this chat")
                        .font(.system(size: 11))
                        .foregroundColor(KBColors.textDim)
                }

                Spacer()

                // Cancel — return to idle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.isCollapsed = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.surface)
    }
}
```

- [ ] **Step 4: Add `startRenameContact()` to `KeyboardModel`**

Inside `KeyboardModel`, add this method after `regenerate()`:

```swift
func startRenameContact() {
    let name = contactName ?? ""
    let allContacts = AppGroupService.shared.loadContacts()
    let candidates = allContacts.filter {
        $0.displayName.localizedCaseInsensitiveContains(name)
    }
    withAnimation(.easeInOut(duration: 0.18)) {
        state = .disambiguate(name: name, candidates: candidates)
    }
}
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: neutral color palette, de-amberize segmented control, rewrite capture bar

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Idle — wide "Capture this chat" primary button

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
            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    model.isCollapsed = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.rear.camera")
                        .font(.system(size: 14))
                    Text("Capture this chat")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Text("Minimises the keyboard so you can triple-tap to screenshot")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Email idle

    private var emailContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button { model.generateEmailReply() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 14))
                    Text("Generate from clipboard")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Text("Copy the email you're replying to, then tap above")
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
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
feat: idle chat — wide amber 'Capture this chat' primary button replaces instruction card

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Replies — carousel pager + wide Insert + tone strip at bottom

**Files:**
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`
- Modify: `ReplrKeyboard/Views/ReplyListView.swift`

This task rebuilds the replies screen. `EmailReplyPagerView` becomes `ReplyCarouselView` (unified for both chat and email). `ReplyListView` and `ReplyRowView` are deleted. `RepliesPanelView` is rewritten to use the carousel + wide Insert button + tone strip.

- [ ] **Step 1: Rewrite `ReplyListView.swift` — keep only `ReplyCarouselView`**

Replace the entire `ReplyListView.swift` file:

```swift
import SwiftUI

// MARK: - Unified reply carousel (chat + email)

struct ReplyCarouselView: View {
    let replies: [String]
    let lastInsertedReply: String?
    @Binding var currentPage: Int

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                ScrollView(.vertical, showsIndicators: false) {
                    Text(reply)
                        .font(.system(size: 15))
                        .foregroundColor(
                            reply == lastInsertedReply
                                ? KBColors.textDim
                                : KBColors.textPrimary
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
```

- [ ] **Step 2: Rewrite `RepliesPanelView.swift`**

Replace the entire `RepliesPanelView.swift` file:

```swift
import SwiftUI

struct RepliesPanelView: View {
    @ObservedObject var model: KeyboardModel
    let replies: [String]

    @State private var currentPage: Int = 0

    private var currentReply: String {
        replies.indices.contains(currentPage) ? replies[currentPage] : ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode segmented control only — tone moves to bottom
            ModeSegmentedControl(model: model)
                .padding(.bottom, 4)
                .background(KBColors.deep)
                .overlay(alignment: .bottom) { KBColors.borderHair.frame(height: 0.5) }

            // Contact header: name + rename + N of M
            if let name = model.contactName {
                contactHeader(name)
                KBColors.borderHair.frame(height: 0.5)
            }

            // Reply carousel
            ReplyCarouselView(
                replies: replies,
                lastInsertedReply: model.lastInsertedReply,
                currentPage: $currentPage
            )

            // Page dots
            pageDots
                .padding(.vertical, 6)

            KBColors.borderHair.frame(height: 0.5)

            // Action row: wide Insert primary + Edit secondary
            actionRow
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            KBColors.borderHair.frame(height: 0.5)

            // Tone strip at bottom + regenerate button
            toneRow
        }
        .background(KBColors.background)
    }

    // MARK: - Contact header

    private func contactHeader(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Text(name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Button {
                    model.startRenameContact()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(KBColors.textPrimary)
            .padding(.leading, 14)

            Spacer()

            if replies.count > 1 {
                Text("\(currentPage + 1) of \(replies.count)")
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
                    .padding(.trailing, 14)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<replies.count, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? KBColors.accent : KBColors.textDim.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.15), value: currentPage)
            }
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private var actionRow: some View {
        if let sentReply = model.lastInsertedReply {
            // Sent state: undo button full width
            HStack(spacing: 8) {
                Text(sentReply)
                    .font(.system(size: 12))
                    .foregroundColor(KBColors.textDim)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { model.onUndoInsert?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Undo")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(KBColors.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(KBColors.undoBtnBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(KBColors.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.2), value: model.lastInsertedReply)
        } else {
            // Normal state: Insert primary + Edit secondary
            HStack(spacing: 8) {
                Button(action: { model.selectReply(currentReply) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Insert reply")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(KBColors.accentFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(KBColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert reply")

                Button("Edit") { model.editReply(currentReply) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KBColors.textPrimary)
                    .frame(width: 56, height: 42)
                    .background(KBColors.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(KBColors.borderHair, lineWidth: 0.5)
                    )
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tone row at bottom + regenerate

    private var toneRow: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(
                        model.tones.filter { model.inputMode == .chat || $0.name != "Dating" }
                    ) { tone in
                        TonePill(
                            name: tone.name,
                            isSelected: tone.name == model.selectedTone.name,
                            action: {
                                model.selectTone(tone)
                                if model.inputMode == .email {
                                    model.generateEmailReply()
                                } else {
                                    model.regenerate()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            KBColors.borderDim.frame(width: 0.5, height: 16)

            Button { model.regenerate() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundColor(KBColors.textDim)
                    .frame(width: 40, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New replies")

            if model.needsGlobeKey {
                KBColors.borderDim.frame(width: 0.5, height: 16)
                Button { model.onSwitchKeyboard?() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(KBColors.textDim)
                        .frame(width: 36, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .overlay(alignment: .top) { KBColors.borderHair.frame(height: 0.5) }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/RepliesPanelView.swift \
        Replr/ReplrKeyboard/Views/ReplyListView.swift
git commit -m "$(cat <<'EOF'
feat: replies — carousel pager, wide Insert primary, tone strip at bottom, rename button

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Error — wide amber "Try again" primary

**Files:**
- Modify: `ReplrKeyboard/Views/ErrorPanelView.swift`

- [ ] **Step 1: Replace the entire file**

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
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(KBColors.accent.opacity(0.85))
                .padding(.bottom, 8)

            Text("Couldn't generate replies")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KBColors.textPrimary)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(KBColors.textDim)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.top, 4)

            Spacer(minLength: 0)

            Button { model.retryGeneration() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                    Text("Try again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KBColors.accentFg)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(KBColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
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
feat: error panel — wide amber 'Try again' primary button

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Loading — card-shaped skeleton matching reply card footprint

**Files:**
- Modify: `ReplrKeyboard/Views/LoadingPanelView.swift`

- [ ] **Step 1: Replace the entire file**

The loading panel shows a card-shaped skeleton in the same position the reply carousel will occupy, so the transition feels seamless.

```swift
import SwiftUI

struct LoadingPanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            KeyboardHeader(model: model, isToneDimmed: true)

            // Skeleton card — same shape/position as the reply card in RepliesPanelView
            skeletonCard
                .padding(.horizontal, 10)
                .padding(.vertical, 10)

            Spacer(minLength: 0)

            // Status line
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .tint(KBColors.textDim)
                Text("Generating replies…")
                    .font(.system(size: 11))
                    .foregroundColor(KBColors.textDim)
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KBColors.background)
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonLine(fraction: 0.92, pulse: false)
            SkeletonLine(fraction: 1.00, pulse: true)
            SkeletonLine(fraction: 0.75, pulse: false)
            SkeletonLine(fraction: 0.88, pulse: true)
            SkeletonLine(fraction: 0.55, pulse: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KBColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KBColors.borderHair, lineWidth: 0.5)
        )
    }
}
```

Also update `SkeletonLine` in `KeyboardView.swift` to use the neutral `skeletonHighlight` token already in `KBColors`:

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
                        .init(color: KBColors.surface, location: 0),
                        .init(color: KBColors.skeletonHighlight, location: shimmer ? 0.5 : 0.15),
                        .init(color: KBColors.surface, location: 1),
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

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/Views/LoadingPanelView.swift \
        Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: loading — card-shaped skeleton with shimmer matches reply card footprint

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update keyboard heights

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Update height values in the `stateCancellable` sink**

Find the `switch state` block inside the `stateCancellable` sink (around line 93–103). Change:
- `loading` from `200` → `230`
- `error` from `200` → `240`
- `replies` chat formula: keep `max(200, min(340, 100 + CGFloat(replies.count) * 52))` → change to fixed `360`
- `replies` email: keep `380`

Replace the height-assignment block:

```swift
let height: CGFloat
switch state {
case .idle:         height = 270
case .loading:      height = 230
case .error:        height = 240
case .disambiguate: height = 300
case .replies:
    height = inputMode == .email ? 380 : 360
}
self.setHeight(height)
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project /Users/WORK2/Desktop/DesktopCloud/Replr/Replr/Replr.xcodeproj \
  -scheme ReplrKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/ReplrKeyboard/KeyboardViewController.swift
git commit -m "$(cat <<'EOF'
feat: keyboard heights — replies=360, loading=230, error=240

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Heights Summary

| State        | Height  |
|--------------|---------|
| Idle         | 270px   |
| Loading      | 230px   |
| Error        | 240px   |
| Disambiguate | 300px   |
| Replies (chat) | 360px |
| Replies (email) | 380px |
| Collapsed    | 44px    |
| Capturing    | 0px     |

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| Neutral dark surfaces — no warm brown tint | Task 1 |
| Amber as spotlight only — segmented control de-amberized | Task 1 |
| Capture bar — explicit triple-tap instruction + animated glyph + cancel | Task 1 |
| `startRenameContact()` on `KeyboardModel` | Task 1 |
| Idle chat — wide amber "Capture this chat" primary button | Task 2 |
| Idle email — wide amber "Generate from clipboard" primary button | Task 2 |
| Replies — single carousel for chat AND email | Task 3 |
| Replies — contact name capitalized + ✎ rename button | Task 3 |
| Replies — "N of M" counter | Task 3 |
| Replies — wide amber "Insert reply" primary | Task 3 |
| Replies — "Edit" neutral secondary beside Insert | Task 3 |
| Replies — tone strip at BOTTOM (not in header) | Task 3 |
| Replies — tapping tone regenerates (email: auto; chat: → idle) | Task 3 |
| Replies — ↻ regenerate button next to tone strip | Task 3 |
| Replies — undo state replaces Insert/Edit | Task 3 |
| Error — wide amber "Try again" primary | Task 4 |
| Error — two-line message (title + detail) | Task 4 |
| Loading — card-shaped skeleton | Task 5 |
| Height updates | Task 6 |

**Items NOT in this plan (deferred):**
- Compact tone chip in idle state (requires reliable sheet support in keyboard extensions — unreliable in iOS)
- First-run coachmark on capture bar
- Live clipboard status line in email idle (requires reading clipboard on every render)
- Skeleton card transition animation matching reply card stagger
- "swipe for more" first-run carousel affordance

**No placeholders present.** All steps have complete Swift code.

**Type consistency:** `RepliesPanelView` now directly calls `model.selectReply()`, `model.editReply()`, `model.regenerate()`, `model.generateEmailReply()` — all existing on `KeyboardModel`. `startRenameContact()` is added in Task 1. `ReplyCarouselView` takes `replies: [String]`, `lastInsertedReply: String?`, `currentPage: Binding<Int>` — used correctly in `RepliesPanelView`.

**One note on `TonePill` in replies tone row:** When user taps a tone on the replies screen, the action calls `model.selectTone(tone)` then `model.regenerate()` (chat) or `model.generateEmailReply()` (email). For email, this re-runs generation from clipboard immediately. For chat, it goes back to idle — the user re-taps "Capture this chat." This is by design (architecture constraint: keyboard extension cannot store the screenshot).
