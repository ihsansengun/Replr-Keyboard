# Companion App Brand UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace native iOS tab bar, filter chips, and Clear All button in the companion app with Replr brand kit equivalents.

**Architecture:** Three independent changes applied in order — extend the shared `Chip` component with an optional icon slot, update `CaptureLogView` to use it, then replace `TabView` with a custom `CustomTabBar` view driven by a `@State var selectedTab` in `ContentView`.

**Tech Stack:** SwiftUI, `ReplrTheme`, `ReplrComponents` (shared design system)

---

## File Map

| File | Change |
|---|---|
| `Shared/ReplrComponents.swift` | Add `icon: String? = nil` param to `Chip` |
| `Replr/Replr/Features/Captures/CaptureLogView.swift` | Swap `filterChip` to use `Chip`; simplify Clear All button |
| `Replr/Replr/App/CustomTabBar.swift` | **New** — `TabSelection` enum + `CustomTabBar` view |
| `Replr/Replr/App/ReplrApp.swift` | Replace `TabView` with custom tab switcher; remove UITabBar appearance code |

---

## Task 1: Add optional icon to `Chip`

**Files:**
- Modify: `Shared/ReplrComponents.swift` (around line 171)

The existing `Chip` only renders a text label. The filter chips need to show a `sparkles` SF Symbol for contacts with memory. Add an optional `icon` parameter so the same component covers both cases.

- [ ] **Open `Shared/ReplrComponents.swift` and locate `struct Chip` (line 171).**

- [ ] **Replace the struct with the version below** (only the struct definition changes — no other code in the file is touched):

```swift
struct Chip: View {
    let label: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(ReplrTheme.Font.footnote)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
            }
            .foregroundColor(isSelected ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? ReplrTheme.Color.accentSubtle : ReplrTheme.Color.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? ReplrTheme.Color.accent.opacity(0.55)
                            : ReplrTheme.Color.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected
                    ? ReplrTheme.Color.accent.opacity(0.20)
                    : .black.opacity(0.08),
                radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .animation(ReplrTheme.Motion.expressive, value: isSelected)
    }
}
```

- [ ] **Build the project (⌘B).** Confirm 0 errors — the added `icon` param has a default value so all existing `Chip(...)` call sites compile unchanged.

- [ ] **Commit:**
```bash
git add Shared/ReplrComponents.swift
git commit -m "feat: add optional icon param to Chip component"
```

---

## Task 2: Brand the filter chips and Clear All button

**Files:**
- Modify: `Replr/Replr/Features/Captures/CaptureLogView.swift` (lines 158–243)

Two changes in one commit:
1. Replace the hand-rolled `filterChip` helper with `Chip`.
2. Strip the capsule background/border from the Clear All toolbar button.

- [ ] **Replace the `filterChip` helper** (lines 217–243) with:

```swift
@ViewBuilder
private func filterChip(label: String, id: UUID?) -> some View {
    let isSelected = vm.selectedContactID == id
    let showSparkles = id.map { contactHasMemory(id: $0) && memoryEnabled } ?? false
    Chip(
        label: label,
        isSelected: isSelected,
        icon: showSparkles ? "sparkles" : nil
    ) {
        vm.selectedContactID = id
    }
    .frame(maxWidth: 160)
}
```

- [ ] **Replace the Clear All toolbar button label** (lines 161–172) with a plain text button:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button("Clear All") { vm.clearAll() }
        .font(ReplrTheme.Font.callout)
        .foregroundStyle(ReplrTheme.Color.danger)
}
```

Remove the old `.buttonStyle(.plain)` wrapper — the new form uses the default button style.

- [ ] **Build (⌘B).** 0 errors.

- [ ] **Run on simulator.** Navigate to the Replies tab. Verify:
  - Filter chips use the brand style (surface background, teal border + tint when selected, sparkles icon on contacts with memory)
  - "Clear All" is plain danger-colored text, no capsule border
  - Tapping "Clear All" still triggers the confirmation and clears sessions

- [ ] **Commit:**
```bash
git add "Replr/Replr/Features/Captures/CaptureLogView.swift"
git commit -m "feat: replace filter chips and Clear All with brand components"
```

---

## Task 3: Create `CustomTabBar`

**Files:**
- Create: `Replr/Replr/App/CustomTabBar.swift`

This file owns the `TabSelection` enum (used by both the bar and `ContentView`) and the `CustomTabBar` view.

- [ ] **Create `Replr/Replr/App/CustomTabBar.swift`** with the following content:

```swift
import SwiftUI

enum TabSelection: Hashable { case replies, memory, settings }

struct CustomTabBar: View {
    @Binding var selection: TabSelection

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.replies,  icon: "clock",      label: "Replies")
            tabButton(.memory,   icon: "brain",       label: "Memory")
            tabButton(.settings, icon: "gearshape",   label: "Settings")
        }
        .frame(height: 56)
        .background(ReplrTheme.Color.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            ReplrTheme.Color.glassBorder.frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: TabSelection, icon: String, label: String) -> some View {
        let active = selection == tab
        Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(ReplrTheme.Font.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(active ? ReplrTheme.Color.accent : ReplrTheme.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                    .fill(active ? ReplrTheme.Color.accent.opacity(0.12) : .clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .animation(ReplrTheme.Motion.quick, value: active)
    }
}
```

- [ ] **Add the file to the Xcode project.** In Xcode, right-click the `App/` group → Add Files → select `CustomTabBar.swift`. Confirm the `Replr` target is checked.

- [ ] **Build (⌘B).** 0 errors.

- [ ] **Commit:**
```bash
git add "Replr/Replr/App/CustomTabBar.swift"
git commit -m "feat: add CustomTabBar with brand surface style and teal active pill"
```

---

## Task 4: Wire `CustomTabBar` into `ContentView` and clean up

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`

Replace `TabView` in `ContentView` with the custom bar, and remove the now-unused `UITabBar` appearance code from `applyBrandAppearance()`.

- [ ] **Replace `ContentView`** (lines 82–98) with:

```swift
struct ContentView: View {
    @State private var selectedTab: TabSelection = .replies

    var body: some View {
        ZStack {
            RepliesView()
                .opacity(selectedTab == .replies ? 1 : 0)
                .allowsHitTesting(selectedTab == .replies)
            MemoryView()
                .opacity(selectedTab == .memory ? 1 : 0)
                .allowsHitTesting(selectedTab == .memory)
            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $selectedTab)
        }
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
        }
    }
}
```

- [ ] **Remove the UITabBar appearance block** from `applyBrandAppearance()`. Delete these lines (around 47–51):

```swift
let tab = UITabBarAppearance()
tab.configureWithOpaqueBackground()
tab.backgroundColor = surfaceColor
UITabBar.appearance().standardAppearance = tab
UITabBar.appearance().scrollEdgeAppearance = tab
```

- [ ] **Remove the `surfaceColor` local variable** from `applyBrandAppearance()` (lines 25–29) since it is no longer referenced:

```swift
// DELETE this block:
let surfaceColor = UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 0.075, green: 0.098, blue: 0.161, alpha: 1) // #131929
        : UIColor(red: 0.992, green: 0.988, blue: 0.980, alpha: 1) // #FDFCFA
}
```

- [ ] **Build (⌘B).** 0 errors.

- [ ] **Run on simulator and verify:**
  - Tab bar shows at the bottom with `#131929` surface background and 1px glass border on top
  - Active tab has a teal-tinted rounded pill behind icon+label; icon and label are teal
  - Inactive tabs are `textSecondary` with no background
  - Switching tabs works; each screen retains its scroll position / navigation state
  - NavigationStack inside Replies works correctly (tapping a session row pushes the detail)
  - Home indicator area is clear of the tab bar on notchless iPhones

- [ ] **Commit:**
```bash
git add "Replr/Replr/App/ReplrApp.swift"
git commit -m "feat: replace TabView with CustomTabBar, remove native tab appearance code"
```
