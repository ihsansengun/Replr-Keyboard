# Keyboard Idle + Capture Bar v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement steps 1–2 of the Replr v2 redesign: full ReplrTheme v2 token migration, updated keyboard idle screen (coral CTA + sub-caption), and redesigned capture bar (surface card with coral left border, animated TapGlyph, first-run coachmark).

**Architecture:** Pure view-layer changes. No state machine, networking, or data model changes. `ReplrTheme.swift` gets the complete v2 token overhaul; `ReplrComponents.swift` gains `ReplrMark`; `KeyboardView.swift` and `IdlePanelView.swift` get updated layouts; `KeyboardViewController.swift` gets a height fix.

**Tech Stack:** SwiftUI, UIKit keyboard extension (`UIInputViewController`), `UserDefaults` via App Group (`group.com.ihsan.replr`), SF Symbols, SF Pro Rounded.

---

## File Map

| File | Change |
|------|--------|
| `Shared/ReplrTheme.swift` | Replace Color enum, Radius enum; add Motion constants; remove `highlight` from `ElevatedSurface` |
| `Shared/ReplrComponents.swift` | Add `ReplrMark` view |
| `ReplrKeyboard/Views/KeyboardView.swift` | Rewrite `ModeSegmentedControl`; update `KeyboardHeader`; add `TapGlyph` + `CoachmarkBalloon`; rewrite `CollapsedStripView` |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Rewrite `chatContent`; update `emailContent` |
| `ReplrKeyboard/Views/RepliesPanelView.swift` | Add horizontal padding to bare `ModeSegmentedControl` usage (2-line fix to prevent edge-to-edge stretch after Task 3) |
| `ReplrKeyboard/KeyboardViewController.swift` | Change collapsed height from 44 → 64 |

---

## Task 1: Replace ReplrTheme Color enum

**Files:**
- Modify: `Shared/ReplrTheme.swift`

Context: The current `accent` is adaptive gray (near-black in dark mode). v2 makes it fixed coral `#FF5A4D` globally. `border`/`borderStrong` switch from hex to rgba. New tokens: `surfaceRaisedHi`, `accentSoft`. Remove `highlight` (used only in `ElevatedSurface` which we fix in Task 2).

- [ ] Replace the entire `enum Color { ... }` block in `Shared/ReplrTheme.swift` with:

```swift
enum Color {
    static let bg              = SwiftUI.Color(light: .init(hex: 0xF5F5F5), dark: .init(hex: 0x0A0A0B))
    static let surface         = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x131318))
    static let surfaceRaised   = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x1E1E25))
    static let surfaceRaisedHi = SwiftUI.Color(light: .init(hex: 0xECECEE), dark: .init(hex: 0x2A2A33))
    static let surfaceSunken   = SwiftUI.Color(light: .init(hex: 0xECECEE), dark: .init(hex: 0x0A0A0B))
    static let surfaceGlass    = SwiftUI.Color(light: SwiftUI.Color(hex: 0xFFFFFF, alpha: 0.72),
                                                dark: SwiftUI.Color(hex: 0x1E1E25, alpha: 0.72))

    static let border          = SwiftUI.Color(light: .init(white: 0, opacity: 0.08),
                                                dark: .init(white: 1, opacity: 0.07))
    static let borderStrong    = SwiftUI.Color(light: .init(white: 0, opacity: 0.14),
                                                dark: .init(white: 1, opacity: 0.12))

    static let textPrimary     = SwiftUI.Color(light: .init(hex: 0x161618), dark: .init(hex: 0xF4F4F2))
    static let textSecondary   = SwiftUI.Color(light: .init(hex: 0x5C5C61), dark: .init(hex: 0x8E8E92))
    static let textTertiary    = SwiftUI.Color(light: .init(hex: 0x97979C), dark: .init(hex: 0x5C5C60))

    // Fixed coral — not adaptive. One coral per screen.
    static let accent          = SwiftUI.Color(hex: 0xFF5A4D)
    static let accentPressed   = SwiftUI.Color(hex: 0xB43E35)
    static let onAccent        = SwiftUI.Color(hex: 0x1A0707)
    static let accentSubtle    = SwiftUI.Color(hex: 0xFF5A4D, alpha: 0.12)
    static let accentSoft      = SwiftUI.Color(hex: 0xFF5A4D, alpha: 0.12)

    static let danger          = SwiftUI.Color(light: .init(hex: 0xC4453F), dark: .init(hex: 0xE06A66))
    static let success         = SwiftUI.Color(light: .init(hex: 0x3F7A52), dark: .init(hex: 0x4ADE80))
}
```

- [ ] Build to confirm no compile errors from removed `highlight` token (Task 2 fixes the one usage):

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: one error referencing `highlight` in `ElevatedSurface`. That's fine — fixed next task.

---

## Task 2: Update Radius enum, add Motion constants, remove `highlight` from ElevatedSurface

**Files:**
- Modify: `Shared/ReplrTheme.swift`

- [ ] Replace the `enum Radius { ... }` block with:

```swift
enum Radius {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let full: CGFloat = 999
}
```

- [ ] Add three lines to the existing `enum Motion { ... }` block (after the existing `expressive` line):

```swift
static let shimmer   = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
static let pulse     = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
static let coachmark = Animation.easeOut(duration: 0.24)
```

- [ ] In `ElevatedSurface.body`, remove the `.overlay(alignment: .top)` block that references `highlight`. Replace the `case .level1, .level2:` branch with:

```swift
case .level1, .level2:
    content
        .shadow(
            color: scheme == .dark
                ? Color(white: 0, opacity: 0.55)
                : Color(white: 0, opacity: 0.06),
            radius: scheme == .dark ? 10 : 2, x: 0,
            y: scheme == .dark ? 6 : 1
        )
        .shadow(
            color: scheme == .dark
                ? .clear
                : Color(white: 0, opacity: 0.06),
            radius: 10, x: 0, y: 6
        )
```

- [ ] Build — must succeed with zero errors:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add Shared/ReplrTheme.swift
git commit -m "$(cat <<'EOF'
feat: migrate ReplrTheme to v2 tokens — coral accent, updated surfaces/radii/motion

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `ReplrMark` to ReplrComponents

**Files:**
- Modify: `Shared/ReplrComponents.swift`

- [ ] Append the following view to the end of `Shared/ReplrComponents.swift` (after the closing `}` of `ScreenScaffold`):

```swift
// MARK: - ReplrMark

struct ReplrMark: View {
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 3) {
            Text("replr")
                .font(.system(size: size, weight: .medium, design: .rounded))
                .tracking(size * -0.04)
                .foregroundColor(ReplrTheme.Color.textPrimary)
            Circle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: size * 0.29, height: size * 0.29)
        }
    }
}
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add Shared/ReplrComponents.swift
git commit -m "$(cat <<'EOF'
feat: add ReplrMark component — wordmark with coral dot

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Rewrite `ModeSegmentedControl` (text-only, intrinsic width)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`
- Modify: `ReplrKeyboard/Views/RepliesPanelView.swift`

Context: The current `ModeSegmentedControl` has icons and uses `.padding(.horizontal, 7)` to position itself. v2 is text-only and intrinsically sized (no external horizontal padding — the parent handles it). `RepliesPanelView` uses it bare; we add `.padding(.horizontal, 16)` there to prevent edge-to-edge stretch.

- [ ] In `KeyboardView.swift`, replace the entire `struct ModeSegmentedControl` (lines ~230–276) with:

```swift
struct ModeSegmentedControl: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 2) {
            segmentBtn(mode: .chat,  label: "Chat")
            segmentBtn(mode: .email, label: "Email")
        }
        .padding(3)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                .stroke(ReplrTheme.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentBtn(mode: KeyboardInputMode, label: String) -> some View {
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
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? ReplrTheme.Color.textPrimary : ReplrTheme.Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? ReplrTheme.Color.surfaceRaised : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}
```

- [ ] In `RepliesPanelView.swift`, update the bare `ModeSegmentedControl` usage (lines ~14–19) to add horizontal padding and an HStack so the intrinsically-sized control doesn't stretch edge-to-edge:

```swift
// Replace:
ModeSegmentedControl(model: model)
    .padding(.bottom, 4)
    .background(ReplrTheme.Color.bg)
    .overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }

// With:
HStack {
    ModeSegmentedControl(model: model)
    Spacer()
}
.padding(.horizontal, 16)
.padding(.bottom, 4)
.background(ReplrTheme.Color.bg)
.overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/Views/KeyboardView.swift ReplrKeyboard/Views/RepliesPanelView.swift
git commit -m "$(cat <<'EOF'
feat: ModeSegmentedControl — text-only tabs, intrinsic width, v2 surface tokens

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update `KeyboardHeader` to add Replr mark

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: `KeyboardHeader` currently wraps `ModeSegmentedControl` alone in a `VStack`. v2 puts it in an `HStack` with `ReplrMark` on the right.

- [ ] In `KeyboardView.swift`, replace the `struct KeyboardHeader` body (lines ~330–348) with:

```swift
struct KeyboardHeader: View {
    @ObservedObject var model: KeyboardModel
    var isSegmentedDisabled: Bool = false
    var isToneHidden: Bool = false
    var isToneDimmed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ModeSegmentedControl(model: model)
                    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
                    .allowsHitTesting(!isSegmentedDisabled)
                Spacer()
                ReplrMark(size: 14)
                    .opacity(isSegmentedDisabled ? 0.4 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if !isToneHidden {
                ToneRow(model: model, isDimmed: isToneDimmed)
            }
        }
        .background(ReplrTheme.Color.bg)
        .overlay(alignment: .bottom) { ReplrTheme.Color.border.frame(height: 0.5) }
    }
}
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: KeyboardHeader — add ReplrMark to right of segmented control

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Rewrite `IdlePanelView` chat + email content

**Files:**
- Modify: `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] Replace the `chatContent` computed property (lines ~22–56) with:

```swift
private var chatContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text("Capture this chat")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(ReplrTheme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ReplrTheme.Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)

        Text("Minimises the keyboard so you can double-tap to screenshot")
            .font(.system(size: 12))
            .foregroundColor(ReplrTheme.Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```

- [ ] In `emailContent`, update the Button label (lines ~64–79) to use v2 button height, radius, and icon:

```swift
// Replace the existing Button in emailContent with:
Button { model.generateEmailReply() } label: {
    HStack(spacing: 8) {
        Image(systemName: hasClipboardText ? "doc.on.clipboard.fill" : "doc.on.clipboard")
            .font(.system(size: 14))
        Text("Generate from clipboard")
            .font(.system(size: 14, weight: .semibold))
    }
    .foregroundColor(hasClipboardText ? ReplrTheme.Color.onAccent : ReplrTheme.Color.textSecondary)
    .frame(maxWidth: .infinity)
    .frame(height: 48)
    .background(ReplrTheme.Color.accent.opacity(hasClipboardText ? 1.0 : 0.30))
    .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
}
.buttonStyle(.plain)
.padding(.horizontal, 16)
.disabled(!hasClipboardText)
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/Views/IdlePanelView.swift
git commit -m "$(cat <<'EOF'
feat: keyboard idle — coral 48pt CTA, sparkles icon, left-aligned caption, v2 email button

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `TapGlyph` + `CoachmarkBalloon` views

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Add both new views before the `CollapsedStripView` struct (around line 174).

- [ ] Insert `TapGlyph` into `KeyboardView.swift`, before `struct CollapsedStripView`:

```swift
// MARK: - TapGlyph

struct TapGlyph: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ReplrTheme.Color.textSecondary, lineWidth: 1.2)
                .frame(width: 18, height: 24)
            Circle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: 4, height: 4)
                .opacity(pulse ? 1.0 : 0.35)
            Circle()
                .stroke(ReplrTheme.Color.accent, lineWidth: 0.8)
                .frame(width: 9, height: 9)
                .opacity(pulse ? 0.4 : 0.1)
        }
        .frame(width: 22, height: 28)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] Insert `CoachmarkBalloon` immediately after `TapGlyph`, still before `CollapsedStripView`:

```swift
// MARK: - CoachmarkBalloon

struct CoachmarkBalloon: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 1)
            Text("① Keyboard's minimised. ② Double-tap the back.")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(2)
        }
        .foregroundColor(ReplrTheme.Color.onAccent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .fill(ReplrTheme.Color.accent)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(x: 20, y: 5)
        }
        .accessibilityLabel("Coachmark: Keyboard's minimised. Double-tap the back.")
    }
}
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: add TapGlyph and CoachmarkBalloon views for capture bar

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Rewrite `CollapsedStripView`

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

Context: The capture bar replaces the full keyboard when collapsed. It shows a surface card with a 3pt coral left border, `TapGlyph`, instruction text, and a × cancel. The `CoachmarkBalloon` floats above — shown once per install. No mode header shown in this state (matches the design — `KbCaptureBar` is standalone).

Context for height: the coachmark adds ~48pt above the card. `KeyboardViewController` reads `coachmarkSeen` to set 116pt on first collapse, 64pt thereafter (Task 9). On first collapse the coachmark balloon + card both fit. After the × is tapped, `coachmarkSeen` is written `true`; the next collapse uses 64pt.

- [ ] Replace the entire `struct CollapsedStripView` (lines ~174–226) with:

```swift
struct CollapsedStripView: View {
    @ObservedObject var model: KeyboardModel
    @State private var showCoachmark: Bool = false

    private let coachmarkKey = "keyboard.coachmarkSeen"

    var body: some View {
        VStack(spacing: 0) {
            // Coachmark — first run only, sits above the capture card
            if showCoachmark {
                CoachmarkBalloon()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .transition(.opacity.animation(ReplrTheme.Motion.coachmark))
            }

            // Capture card
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

                Button {
                    dismissCoachmark()
                    withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
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
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ReplrTheme.Color.bg)
        .onAppear {
            let seen = UserDefaults(suiteName: Constants.appGroupID)?
                .bool(forKey: coachmarkKey) ?? false
            if !seen {
                withAnimation(ReplrTheme.Motion.coachmark) { showCoachmark = true }
            }
        }
        .onDisappear {
            dismissCoachmark()
        }
    }

    private func dismissCoachmark() {
        guard showCoachmark else { return }
        withAnimation(ReplrTheme.Motion.coachmark) { showCoachmark = false }
        UserDefaults(suiteName: Constants.appGroupID)?
            .set(true, forKey: coachmarkKey)
    }
}
```

- [ ] Build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "$(cat <<'EOF'
feat: capture bar v2 — surface card, coral left border, TapGlyph, first-run coachmark

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update collapsed height in `KeyboardViewController`

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

Context: The capture card is ~64pt tall. The first-run coachmark adds ~48pt above it. `KeyboardViewController` reads `coachmarkSeen` from UserDefaults when setting collapsed height: 116pt if never seen, 64pt once dismissed. The user always dismisses by tapping × (which writes `true`) or via capture completing (`onDisappear` writes `true`). The extra height on first run is a one-time occurrence.

- [ ] In `KeyboardViewController.swift`, in the `stateCancellable` sink closure (around line 90), change:

```swift
// Replace:
if isCollapsed {
    self.setHeight(44)
    return
}

// With:
if isCollapsed {
    let coachmarkSeen = UserDefaults(suiteName: Constants.appGroupID)?
        .bool(forKey: "keyboard.coachmarkSeen") ?? false
    self.setHeight(coachmarkSeen ? 64 : 116)
    return
}
```

- [ ] Build — final clean build:

```bash
xcodebuild build -project Replr/Replr.xcodeproj -scheme Replr -sdk iphonesimulator -configuration Debug 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Commit:

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "$(cat <<'EOF'
feat: increase collapsed keyboard height to 64pt for v2 capture bar

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Verification

After all tasks complete, install the keyboard extension on a device or simulator and confirm:

- [ ] Keyboard idle (chat): coral "Capture this chat" button with sparkles icon, 48pt tall. ToneRow visible below header.
- [ ] Keyboard idle (email): coral "Generate from clipboard" button disabled until text is copied.
- [ ] Header: "Chat | Email" text-only tabs + `replr•` mark on the right.
- [ ] Tap "Capture this chat": keyboard collapses to 64pt capture bar.
- [ ] Capture bar: surface card, coral left border, phone glyph pulsing, instruction text, × cancel.
- [ ] First open: coachmark balloon above card. Tap × or wait for replies — coachmark never shows again.
- [ ] Subsequent opens: no coachmark.
- [ ] Reduce Motion: TapGlyph stays at resting opacity — no animation.
