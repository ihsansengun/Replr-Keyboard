# Companion App Brand UI Redesign

**Date:** 2026-05-26  
**Scope:** Replace native iOS components in the companion app with Replr brand kit equivalents.

---

## What Changes

Three components are out of brand on the current Replies screen and root navigation:

| Component | Current | Target |
|---|---|---|
| Tab bar | Native `TabView` floating gray pill | Custom surface bar, teal-tinted pill behind active item |
| Filter chips | System-style capsule buttons | Brand `Chip` — surface bg, teal border + tint when active |
| Clear All button | Red-bordered native capsule in toolbar | Plain text button, `ReplrTheme.Color.danger` color, no border |

---

## 1. Custom Tab Bar

Replace SwiftUI `TabView` in `ReplrApp.swift` with a manual tab switcher.

**Layout:**
- Full-width bar at the bottom of the screen
- Background: `ReplrTheme.Color.surface` (`#131929`)
- Top border: `ReplrTheme.Color.glassBorder` (1px)
- Three items: Replies (clock), Memory (brain), Settings (gear)
- Each item: icon + label stacked vertically, equal-width columns

**Active state:**
- Background pill behind icon+label: `ReplrTheme.Color.accent.opacity(0.12)`, `cornerRadius: ReplrTheme.Radius.sm`
- Icon and label: `ReplrTheme.Color.accent`

**Inactive state:**
- No background
- Icon and label: `ReplrTheme.Color.textSecondary`

**Safe area:** The bar sits above the home indicator; add `safeAreaInset(edge: .bottom)` so the tab bar is always anchored to the real bottom, clear of the system home indicator.

**Implementation:** Add `CustomTabBar` view + `TabSelection` enum in a new file `Replr/App/CustomTabBar.swift`. `ReplrApp.swift` owns a `@State var selectedTab: TabSelection` and renders the active screen above the bar in a `ZStack` or `VStack`.

---

## 2. Filter Chips (Replies Screen)

The existing chip row in `CaptureLogView.swift` uses ad-hoc capsule buttons. Replace with the shared `Chip` component from `ReplrComponents.swift`.

**Chip spec (already in design system):**
- Height: 34pt, horizontal padding: 12pt
- Background: `ReplrTheme.Color.surface` (unselected) / `ReplrTheme.Color.accent.opacity(0.12)` (selected)
- Border: `ReplrTheme.Color.glassBorder` (unselected) / `ReplrTheme.Color.accent` (selected)
- Label: `ReplrTheme.Font.footnote`, `textSecondary` (unselected) / `accent` + semibold (selected)

No changes to the `Chip` component itself — just swap the existing custom capsule buttons in `CaptureLogView` to use `Chip`.

---

## 3. Clear All Button

**Current:** `.toolbar` item using a custom capsule with red border.  
**Target:** A plain `Button` with `ReplrTheme.Color.danger` foreground color and `.plain` button style. No background, no border. Sits in the same `.navigationBarTrailing` toolbar position.

```swift
Button("Clear All", role: .destructive) { … }
    .foregroundColor(ReplrTheme.Color.danger)
    .font(ReplrTheme.Font.callout)
```

---

## Files Touched

| File | Change |
|---|---|
| `Replr/App/ReplrApp.swift` | Replace `TabView` with custom tab switcher |
| `Replr/App/CustomTabBar.swift` | New file — `CustomTabBar` view + `TabSelection` enum |
| `Replr/Features/Captures/CaptureLogView.swift` | Swap filter chips to `Chip`; update Clear All button |

No changes to `ReplrComponents.swift`, `ReplrTheme.swift`, or any keyboard files.

---

## Out of Scope

- Memory screen, Settings screen, and other screens are already largely on-brand; not touched in this pass.
- No new animations beyond what `Chip` already provides.
- No changes to navigation structure or screen content.
