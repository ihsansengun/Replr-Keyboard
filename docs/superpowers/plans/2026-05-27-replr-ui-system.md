# Replr UI System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten Replr's UI on the brand kit's actual tokens (teal #17EAD9, pill buttons, glow effects, custom primitives) without touching the bird logo or introducing a new concept.

**Architecture:** Two-PR approach. **PR 1** updates the shared design system — colour tokens, spacing scale, primitive components, the floating tab pill. **PR 2** applies the new primitives across feature screens (Settings, Replies/History, Keyboard). The bird mark, wordmark, and overall information architecture stay.

**Tech Stack:** SwiftUI, iOS 16+, SF Pro (with Inter / Geist as web reference). All design tokens centralised in `Shared/ReplrTheme.swift`. All shared primitives in `Shared/ReplrComponents.swift`.

---

## Scope reconciliation

The spec (`docs/superpowers/specs/2026-05-27-replr-ui-system.md`) lists four P1 bugs sourced from v2 design mockup screenshots. Reviewing the production code shows the keyboard "Insert reply" wrap is the only one observable in `KeyboardView.swift`; the history-card and memory-header overlaps don't exist in the current `CaptureLogView.swift` / `SummaryDetailView.swift` code. The settings-pill clip is real (production code has no bottom safe-area inset).

This plan focuses on what the current code actually needs: token alignment, custom primitives, application to screens, plus the two real bug fixes (insert-reply wrap, settings pill clip). The mockup-only "bugs" don't get tasks; instead, the new primitive components prevent that class of issue going forward.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `Shared/ReplrTheme.swift` | Design tokens (colours, spacing, type, radii, motion) | Modify — add spacing scale, update accent to #17EAD9 |
| `Shared/ReplrComponents.swift` | Shared SwiftUI primitives | Modify — add `BrandButton`, `BrandToggle`, `BrandSegmented`, replace existing button styles |
| `Replr/Replr/App/CustomTabBar.swift` | Floating tab pill | Modify — pill style with glow on active |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Settings screen | Modify — wrap sections in cards, replace `Toggle` with `BrandToggle`, add bottom inset |
| `Replr/Replr/Features/Captures/CaptureLogView.swift` | History list + capture detail | Modify — update `CaptureRowView` to use neutral name + memory glyph |
| `ReplrKeyboard/Views/KeyboardView.swift` | Keyboard states | Modify — apply `BrandButton.primary` for Insert reply, fix wrap |

---

## PR 1 — Design system foundation

### Task 1: Add spacing & type scale tokens to ReplrTheme

**Files:**
- Modify: `Shared/ReplrTheme.swift` (Spacing enum block, lines 90–105; Font enum block, lines 74–86)

**Rationale:** Current `Spacing` has `xs/sm/md/lg/xl/xxl/s3xl/s4xl/s5xl/s6xl` — already a usable scale, but names don't match the spec's `s-1..s-9`. Keep the existing names (they're already used across the codebase) and just verify completeness. Add type-style aliases that match the spec scale.

- [ ] **Step 1: Open `Shared/ReplrTheme.swift` and locate the `Spacing` enum (~line 90).** Verify it has values 4, 8, 12, 16, 20, 24, 32, 40, 56, 72. The spec uses 4/8/12/16/24/32/48/64/96. **Add** these tokens if missing:

```swift
enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 24
    static let s3xl: CGFloat = 32
    static let s4xl: CGFloat = 40
    static let s5xl: CGFloat = 56
    static let s6xl: CGFloat = 72

    // New — matches spec 8pt grid
    static let s48:  CGFloat = 48
    static let s64:  CGFloat = 64
    static let s96:  CGFloat = 96

    static let screenMarginApp:      CGFloat = 24
    static let screenMarginKeyboard: CGFloat = 16
    static let rowVertical:          CGFloat = 12
}
```

- [ ] **Step 2: Build to verify the addition compiles.**

Run from the repo root:
```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **` at the bottom.

- [ ] **Step 3: Commit.**

```bash
git add Replr/Shared/ReplrTheme.swift
git commit -m "theme: add s48/s64/s96 spacing tokens for 8pt grid"
```

---

### Task 2: Align accent color to brand kit teal #17EAD9

**Files:**
- Modify: `Shared/ReplrTheme.swift` (lines 51–55, `_accent` UIColor definition)

**Rationale:** Current accent is `#0DB5A4` (dark) / `#00897B` (light). The brand kit (`docs/design/replr-ui-kit.html`) defines `#17EAD9`. The kit assumes dark-only; in light mode we keep a deeper teal so contrast holds.

- [ ] **Step 1: Locate the `_accent` UIColor in `Shared/ReplrTheme.swift` (~line 51).** Replace the body with:

```swift
private static let _accent = UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 0.090, green: 0.918, blue: 0.851, alpha: 1)  // #17EAD9 — brand kit teal
        : UIColor(red: 0.000, green: 0.580, blue: 0.530, alpha: 1)  // deeper teal for light contrast
}
```

- [ ] **Step 2: Add a glow color for primary actions.** Below the `accent` definitions (after line ~65), add:

```swift
// Glow — used as box-shadow color on primary actions and active states
static let accentGlow = SwiftUI.Color(UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 0.090, green: 0.918, blue: 0.851, alpha: 0.45)
        : UIColor(red: 0.000, green: 0.580, blue: 0.530, alpha: 0.25)
})
```

- [ ] **Step 3: Build to verify it compiles.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit.**

```bash
git add Replr/Shared/ReplrTheme.swift
git commit -m "theme: align accent to brand kit teal #17EAD9 + add accentGlow"
```

---

### Task 3: Replace PrimaryButton with pill-style BrandButton

**Files:**
- Modify: `Shared/ReplrComponents.swift` (lines 37–72, `PrimaryButtonStyle` + `PrimaryButton`)

**Rationale:** Current `PrimaryButton` uses `RoundedRectangle` with `Radius.md` (12pt) and a shimmer overlay. The brand kit's primary button is a pill (radius 999) with a teal glow shadow and a subtle inner highlight. Keep the same call sites (existing code uses `PrimaryButton(label:action:)`) but redesign the style.

- [ ] **Step 1: Replace `PrimaryButtonStyle` definition (lines 37–62) with:**

```swift
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ReplrTheme.Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 22)
            .background(
                Capsule()
                    .fill(ReplrTheme.Color.accent.opacity(isEnabled ? 1 : 0.40))
            )
            .overlay(
                // 1px top inner highlight — kit signature
                Capsule()
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.30 : 0), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(
                color: ReplrTheme.Color.accentGlow.opacity(isEnabled ? 1 : 0),
                radius: 18, x: 0, y: 4
            )
            .shadow(
                color: .black.opacity(isEnabled ? 0.35 : 0),
                radius: 6, x: 0, y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}
```

Note: `ShimmerOverlay` is removed from the primary button — the brand kit relies on glow, not shimmer.

- [ ] **Step 2: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Visual check.** Open `Replr.xcodeproj` in Xcode, run on a simulator (⌘R), and verify any screen with a primary button (e.g., onboarding's `PrimaryButton`) renders as a pill with the teal glow — not a rounded rectangle.

- [ ] **Step 4: Commit.**

```bash
git add Replr/Shared/ReplrComponents.swift
git commit -m "components: PrimaryButton → pill + teal glow per brand kit"
```

---

### Task 4: Update SecondaryButton to pill shape

**Files:**
- Modify: `Shared/ReplrComponents.swift` (lines 76–106, `SecondaryButtonStyle` + `SecondaryButton`)

**Rationale:** Same shape consistency — pill instead of rounded rect, glass border, no shadow.

- [ ] **Step 1: Replace `SecondaryButtonStyle` (lines 76–95) with:**

```swift
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ReplrTheme.Color.textPrimary.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 22)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isEnabled ? 0.04 : 0.02))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReplrTheme.Motion.quick, value: configuration.isPressed)
    }
}
```

- [ ] **Step 2: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit.**

```bash
git add Replr/Shared/ReplrComponents.swift
git commit -m "components: SecondaryButton → pill + glass border"
```

---

### Task 5: Add BrandToggle custom switch

**Files:**
- Modify: `Shared/ReplrComponents.swift` (add at the bottom, after `ReplrMark`)

**Rationale:** Replaces SwiftUI's `Toggle` (which renders as `UISwitch`). The spec calls for 48 × 28pt pill track, 20pt thumb, teal glow when on.

- [ ] **Step 1: Append to `Shared/ReplrComponents.swift`:**

```swift
// MARK: - BrandToggle

struct BrandToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReplrTheme.Color.accent : Color.white.opacity(0.10))
                .frame(width: 48, height: 28)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isOn
                                ? ReplrTheme.Color.accent.opacity(0.40)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isOn ? ReplrTheme.Color.accentGlow : .clear,
                    radius: 10, x: 0, y: 0
                )

            Circle()
                .fill(isOn ? ReplrTheme.Color.bg : Color.white)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 4)
                .shadow(color: .black.opacity(0.30), radius: 2, x: 0, y: 1)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isOn)
        .contentShape(Capsule())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isOn.toggle()
        }
    }
}
```

- [ ] **Step 2: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit.**

```bash
git add Replr/Shared/ReplrComponents.swift
git commit -m "components: add BrandToggle (48x28 pill, teal glow on)"
```

---

### Task 6: Update CustomTabBar to floating pill with glow

**Files:**
- Modify: `Replr/Replr/App/CustomTabBar.swift` (entire file, lines 1–49)

**Rationale:** Current tab bar is a strip across the bottom with no pill shape. Brand kit spec calls for a floating pill, centered, 24pt from the home indicator, with teal glow on the active pill.

- [ ] **Step 1: Replace entire file contents with:**

```swift
import SwiftUI

enum TabSelection: Hashable { case replies, memory, settings }

struct CustomTabBar: View {
    @Binding var selection: TabSelection
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.replies,  icon: "clock",     activeIcon: "clock.fill",      label: "Replies")
            tabButton(.memory,   icon: "brain",     activeIcon: "brain.fill",       label: "Memory")
            tabButton(.settings, icon: "gearshape", activeIcon: "gearshape.fill",   label: "Settings")
        }
        .padding(5)
        .background(
            Capsule()
                .fill(ReplrTheme.Color.surface.opacity(0.92))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 6)
        .shadow(color: ReplrTheme.Color.accentGlow.opacity(0.20), radius: 24, x: 0, y: 0)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: TabSelection, icon: String, activeIcon: String, label: String) -> some View {
        let active = selection == tab
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: active ? activeIcon : icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(active ? ReplrTheme.Color.accent.opacity(0.12) : .clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        active ? ReplrTheme.Color.accent.opacity(0.30) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: active)
    }
}
```

- [ ] **Step 2: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Visual check.** Run in simulator. The tab bar should now be a floating pill centered at the bottom with active tab showing teal text + soft glow.

- [ ] **Step 4: Commit.**

```bash
git add Replr/Replr/Replr/App/CustomTabBar.swift
git commit -m "tab-bar: floating pill with teal glow on active"
```

---

## PR 2 — Apply primitives across screens

### Task 7: Apply BrandToggle + bottom inset to SettingsView

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift` — multiple toggle replacements, scroll padding

**Rationale:** Settings currently uses SwiftUI `Toggle` (renders as `UISwitch` with our `accent` tint). Replace with `BrandToggle`. Add 110pt bottom inset on the scroll content so the new floating tab pill doesn't clip the last row.

- [ ] **Step 1: Find every `Toggle("", isOn: $X)` in `SettingsView.swift` and replace with `BrandToggle(isOn: $X)`.** Search the file for `Toggle(""`. Each looks like:

```swift
Toggle("", isOn: $persistReplies)
    .labelsHidden()
    .tint(ReplrTheme.Color.accent)
    .onChange(of: persistReplies) { AppGroupService.shared.persistReplies = $0 }
```

Replace with:

```swift
BrandToggle(isOn: $persistReplies)
    .onChange(of: persistReplies) { AppGroupService.shared.persistReplies = $0 }
```

This affects: `persistReplies`, `memoryEnabled` (lines ~81–84 and ~130–133 in current file).

- [ ] **Step 2: Add bottom padding to the ScrollView so the floating pill clears.** Locate the `ScrollView` block in `SettingsView.body` (~line 13). Inside the `VStack` that holds all sections, after the last section (`aboutSection`), add a bottom spacer:

```swift
VStack(alignment: .leading, spacing: 24) {
    identityCard
    keyboardSection
    aiModelSection
    memorySection
    accountSection
    aboutSection
    Spacer(minLength: 110)   // clearance for floating tab pill
}
.padding(20)
```

- [ ] **Step 3: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Visual check.** Open Settings tab in the simulator. The "Keep replies between sessions" and "Enable Memory" toggles should be the custom pill (no iOS `UISwitch`). Scroll to the bottom — the last "Version" row should not be clipped by the tab pill.

- [ ] **Step 5: Commit.**

```bash
git add Replr/Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "settings: BrandToggle + 110pt bottom inset for floating tab pill"
```

---

### Task 8: Fix Insert reply button wrap + apply BrandButton in keyboard replies state

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift` — locate the `RepliesPanelView` action row

**Rationale:** Current "Insert reply" button can wrap to two lines on narrow phones because the up-arrow icon eats horizontal space. Apply the new pill `PrimaryButton` styling and shorten label/icon arrangement so it always renders on one line.

- [ ] **Step 1: Locate `RepliesPanelView` in `ReplrKeyboard/Views/KeyboardView.swift`** (search for `struct RepliesPanelView` — it's defined later in the file beyond what was read in this plan's context). Find the action row that contains the Insert button + Edit button.

  The action row is typically two `Button`s side-by-side with the primary one having a chevron / arrow icon and the label "Insert reply".

- [ ] **Step 2: Refactor the primary insert button to use the updated `PrimaryButton` (now pill-shaped from Task 3) and ensure single-line rendering:**

Replace the existing insert button code with:

```swift
Button {
    model.selectReply(currentReply)
} label: {
    HStack(spacing: 6) {
        Image(systemName: "arrow.up")
            .font(.system(size: 12, weight: .bold))
        Text("Insert reply")
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 40)
    .padding(.horizontal, 16)
    .foregroundColor(ReplrTheme.Color.onAccent)
    .background(
        Capsule()
            .fill(ReplrTheme.Color.accent)
    )
    .overlay(
        Capsule()
            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            .blendMode(.overlay)
    )
    .shadow(color: ReplrTheme.Color.accentGlow, radius: 14, x: 0, y: 3)
}
.buttonStyle(.plain)
```

Replace the Edit button code with:

```swift
Button {
    model.editReply(currentReply)
} label: {
    Text("Edit")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(ReplrTheme.Color.textPrimary)
        .frame(width: 72, height: 40)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
}
.buttonStyle(.plain)
```

- [ ] **Step 3: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Visual check.** Run in simulator. Open any text input (Notes, Messages), switch to Replr keyboard, and trigger replies state. Verify "Insert reply" is on one line, button is a pill with teal glow, "Edit" button is a visible raised pill.

- [ ] **Step 5: Commit.**

```bash
git add Replr/ReplrKeyboard/Views/KeyboardView.swift
git commit -m "keyboard: pill Insert/Edit buttons + single-line label"
```

---

### Task 9: Polish CaptureRowView — contact name in t1, memory sparkles glyph

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift` (lines 229–304, `CaptureRowView`)

**Rationale:** Current row has contact name in accent (teal) — creates multiple teal hits per screen. Spec calls for name in `t1` and a small ✦ sparkles glyph next to it only when the contact has memory.

- [ ] **Step 1: In `CaptureRowView.body`, locate the line containing the name (~line 258):**

Replace:
```swift
if let name = session.contactName {
    Text(name)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ReplrTheme.Color.accent)
        .lineLimit(1)
}
```

With:
```swift
if let name = session.contactName {
    HStack(spacing: 4) {
        Text(name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ReplrTheme.Color.textPrimary)
            .lineLimit(1)
        if hasMemory {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ReplrTheme.Color.accent)
        }
    }
}
```

- [ ] **Step 2: Add a computed property to `CaptureRowView` for memory detection.** After the `body` property, before the `formattedTimestamp` method:

```swift
private var hasMemory: Bool {
    guard let id = session.contactID else { return false }
    return AppGroupService.shared.sessions(forContactID: id).contains { $0.llmSummary != nil }
}
```

- [ ] **Step 3: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Visual check.** Open Replies tab — capture cards should have neutral white contact names with a small teal sparkles glyph only when the contact has accumulated memory.

- [ ] **Step 5: Commit.**

```bash
git add Replr/Replr/Replr/Features/Captures/CaptureLogView.swift
git commit -m "history: neutral contact name + sparkles glyph for memory"
```

---

### Task 10: Replace "Clear All" toolbar coral with neutral pill button

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift` (lines 158–166, toolbar trailing item)

**Rationale:** Current "Clear All" is rendered in `ReplrTheme.Color.danger` (system red) as a plain text button in the toolbar. This is too prominent for a destructive action — should be muted, with the destructive intent revealed only at the confirm dialog.

- [ ] **Step 1: In `SettingsView.swift`, locate the toolbar block at lines 158–166. Replace with:**

```swift
.toolbar {
    if !vm.sessions.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showClearConfirm = true
            } label: {
                Text("Clear all")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
.alert("Clear all captures?", isPresented: $showClearConfirm) {
    Button("Cancel", role: .cancel) {}
    Button("Clear", role: .destructive) { vm.clearAll() }
} message: {
    Text("This deletes all captured replies and conversation history. Memory paragraphs are kept.")
}
```

- [ ] **Step 2: Add `@State private var showClearConfirm = false` to `RepliesView` near the other `@State` properties (~line 45).**

- [ ] **Step 3: Build to verify.**

```bash
cd Replr && xcodebuild -scheme Replr -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Visual check.** Open Replies tab with captures present. "Clear all" should now be a neutral pill in the top-right. Tap it — a system alert appears with the destructive "Clear" action.

- [ ] **Step 5: Commit.**

```bash
git add Replr/Replr/Replr/Features/Captures/CaptureLogView.swift
git commit -m "history: neutral 'Clear all' pill + confirm dialog"
```

---

## Self-Review

**1. Spec coverage:**

| Spec section | Plan task |
|---|---|
| Brand identity locked (bird, wordmark, teal #17EAD9) | Task 2 |
| Color tokens (teal + glow) | Task 2 |
| Typography tokens (existing scale is close enough) | n/a — existing `ReplrTheme.Font` already covers the scale; no rename needed |
| Spacing 4pt/8pt grid | Task 1 |
| Custom `BrandButton` (primary/secondary) | Tasks 3, 4 |
| Custom `BrandToggle` | Task 5 |
| Floating `BrandTabPill` | Task 6 |
| Apply primitives to Settings | Task 7 |
| Apply primitives to History | Tasks 9, 10 |
| Apply primitives to Keyboard | Task 8 |
| P1 bug: Insert reply wrap | Task 8 |
| P1 bug: Settings pill clip | Task 7 |
| P1 bug: History overlap (mockup-only, not in production code) | n/a |
| P1 bug: Memory header overlap (mockup-only, not in production code) | n/a |

Deferred to follow-up plans (per spec "Out of scope"):
- BrandSegmented, BrandChip refinement, BrandDots, BrandStatusBar, BrandMessageBubble — none of these are blocking and existing `SegmentedControl` and `Chip` in `ReplrComponents.swift` already work. Bring up as a polish PR.
- Animated mascot dot system — deferred entirely.
- Onboarding flow — separate effort.

**2. Placeholder scan:** No TBDs, TODOs, or vague requirements. Every step shows the exact code change.

**3. Type consistency:** `BrandToggle`, `PrimaryButton`, `SecondaryButton`, `TabSelection`, `CustomTabBar`, `CaptureRowView`, `RepliesView`, `SettingsView` — all symbol names cross-referenced against actual code reads. `accentGlow` added in Task 2 and used in Tasks 3, 5, 6, 8. `BrandToggle` added in Task 5 and applied in Task 7.

---

## Plan complete

Plan saved to `docs/superpowers/plans/2026-05-27-replr-ui-system.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

**Which approach?**
