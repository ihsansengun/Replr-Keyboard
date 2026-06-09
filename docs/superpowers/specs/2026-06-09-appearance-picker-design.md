# Appearance Picker — Design Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a three-state Dark / Light / System appearance picker to the Replr companion app's Settings screen.

**Architecture:** Single `@AppStorage` key shared between `ReplrApp` and `SettingsView`; `.preferredColorScheme()` applied at the `WindowGroup` root. No new files, no new service layer.

**Tech Stack:** SwiftUI, `@AppStorage` (UserDefaults), `ColorScheme`.

---

## Data layer

### Storage key
- Key: `"colorSchemeAppearance"` (String)
- Values: `"system"` (default) | `"light"` | `"dark"`
- Stored in standard UserDefaults via `@AppStorage` — no App Group needed (keyboard extension never reads this).

### Resolved scheme
In `ReplrApp`, a computed property converts the raw string to `ColorScheme?`:

```swift
private var resolvedScheme: ColorScheme? {
    switch colorSchemeAppearance {
    case "light": return .light
    case "dark":  return .dark
    default:      return nil   // nil = follow iOS system setting
    }
}
```

`nil` preserves the existing behaviour for all users who never touch the setting.

---

## Wiring — ReplrApp.swift

Add one `@AppStorage` property to `ReplrApp`:

```swift
@AppStorage("colorSchemeAppearance") private var colorSchemeAppearance = "system"
```

Wrap the existing `WindowGroup` body in a `Group` and apply the modifier:

```swift
var body: some Scene {
    WindowGroup {
        Group {
            // … existing if/else (SignInView / OnboardingView / ContentView) unchanged …
        }
        .preferredColorScheme(resolvedScheme)
    }
}
```

No other change to `ReplrApp`.

---

## Settings UI — SettingsView.swift

### New section: Appearance

Inserted between `identityCard` and `aboutYouSection` in the `body` VStack.

```swift
appearanceSection   // new — inserted here
aboutYouSection
keyboardSection
// … rest unchanged
```

### Section implementation

Add `@AppStorage("colorSchemeAppearance") private var colorSchemeAppearance = "system"` to `SettingsView`'s state block.

The section uses a custom 3-segment control identical in structure to `aiModelSection` / `modelOption`:

```
┌─────────────────────────────────────────────┐
│  [iphone]  System  │  [sun.max]  Light  │  [moon]  Dark  │
└─────────────────────────────────────────────┘
  "Overrides the system setting for Replr only."
```

- Outer container: `settingsSection("Appearance") { … }` → gets `brandCard()` automatically
- Inner: `HStack(spacing: 0)` of three `appearanceOption` buttons separated by `glassBorder` hairline dividers (1 pt wide, full height of row)
- Each option: icon (`font(.system(size: 15))`) above label (`font(.system(size: 12, weight: .semibold))`), full-height tap target, `frame(maxWidth: .infinity)`
- Row height: 58 pt (matches `modelOption`)
- Padding: `6 pt` around the HStack (matches `modelOption`)

**Selected state** (matching `modelOption` exactly):
- Background: `ReplrTheme.Color.accentSubtle`
- Text + icon: `ReplrTheme.Color.accent`
- Border overlay: `ReplrTheme.Color.accent.opacity(0.55)`, 1 pt, `RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm)`

**Unselected state:**
- Background: `Color.clear`
- Text + icon: `ReplrTheme.Color.textPrimary` for both (matches `modelOption`)
- No border

**Animation:** `ReplrTheme.Motion.quick` on selection change.

**Footnote** below the card (outside `settingsSection`):
```
"Overrides the system setting for Replr only."
```
`font(.system(size: 12))`, `textSecondary`, `.padding(.horizontal, 4)`.

### Segment definitions

| Value | Icon (SF Symbol) | Label |
|---|---|---|
| `"system"` | `iphone` | System |
| `"light"` | `sun.max` | Light |
| `"dark"` | `moon` | Dark |

---

## Files changed

| File | Change |
|---|---|
| `Replr/Replr/App/ReplrApp.swift` | Add `@AppStorage("colorSchemeAppearance")`, `resolvedScheme` computed var, wrap WindowGroup body in `Group { }.preferredColorScheme(resolvedScheme)` |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Add `@AppStorage("colorSchemeAppearance")`, `appearanceSection` computed var, `appearanceOption` helper, insert section in `body` |

No new files. No backend changes. No App Group or keyboard extension changes.

---

## Out of scope

- Keyboard extension appearance (it follows the host app's trait collection automatically)
- Onboarding screens (they appear before the user reaches Settings; system default is fine)
- Per-screen overrides
