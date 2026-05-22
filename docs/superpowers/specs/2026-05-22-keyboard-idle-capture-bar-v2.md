# Spec · Keyboard Idle + Capture Bar — Replr v2 (Steps 1–2)

**Date:** 2026-05-22
**Scope:** Steps 1 and 2 of the v2 redesign as ordered in `docs/design/README.md`.
**Files changed:** `Shared/ReplrTheme.swift`, `Shared/ReplrComponents.swift`, `ReplrKeyboard/Views/KeyboardView.swift`, `ReplrKeyboard/Views/IdlePanelView.swift`, `ReplrKeyboard/KeyboardViewController.swift`
**Reference:** `docs/design/README.md` · `docs/design/tokens.md` · `docs/design/design_files/src/keyboard.jsx`

---

## 1 · ReplrTheme full v2 token migration

All values in `Shared/ReplrTheme.swift` are updated to match `docs/design/tokens.md` exactly. Light-mode surfaces stay near-white/light-gray. Coral accent is fixed (same in light and dark).

### Color

| Token | Dark hex | Light hex | Notes |
|---|---|---|---|
| `bg` | `#0A0A0B` | `#F5F5F5` | Was `#0B0B0C` dark |
| `surface` | `#131318` | `#FFFFFF` | Was `#161617` |
| `surfaceRaised` | `#1E1E25` | `#FFFFFF` | Was `#202022` |
| `surfaceRaisedHi` | `#2A2A33` | `#ECECEE` | **New token** — hover/active raised |
| `surfaceSunken` | `#0A0A0B` | `#ECECEE` | Unchanged |
| `surfaceGlass` | `rgba(#1E1E25, 0.72)` | `rgba(#FFFFFF, 0.72)` | Unchanged |
| `border` | `rgba(255,255,255, 0.07)` | `rgba(0,0,0, 0.08)` | Was `#2A2A2C` |
| `borderStrong` | `rgba(255,255,255, 0.12)` | `rgba(0,0,0, 0.14)` | Was `#3A3A3D` |
| `textPrimary` / t1 | `#F4F4F2` | `#161618` | Was `#F5F5F6` |
| `textSecondary` / t2 | `#8E8E92` | `#5C5C61` | Was `#9B9B9F` |
| `textTertiary` / t3 | `#5C5C60` | `#97979C` | Was `#65656A` |
| `accent` | `#FF5A4D` | `#FF5A4D` | **Fixed coral, not adaptive** |
| `accentPressed` | `#B43E35` | `#B43E35` | Was adaptive |
| `onAccent` | `#1A0707` | `#1A0707` | **Fixed dark, not adaptive** |
| `accentSubtle` | `rgba(255,90,77, 0.12)` | `rgba(255,90,77, 0.10)` | Was rgba(0,0,0,0.05) |
| `accentSoft` | `rgba(255,90,77, 0.12)` | `rgba(255,90,77, 0.10)` | **New alias** — for memory card tint |
| `danger` | `#E06A66` | `#C4453F` | Unchanged |
| `success` | `#4ADE80` | `#3F7A52` | Unchanged |

Remove `highlight` (was `rgba(255,255,255,0.06)`) — replaced by `surfaceRaisedHi` semantics.

### Radius

| Token | Old | New |
|---|---|---|
| `sm` | 10 | 8 |
| `md` | 15 | 12 |
| `lg` | 18 | 16 |
| `xl` | 26 | 20 |
| `full` | 999 | 999 |

Add `xs: CGFloat = 4` (new — for small swatches, segmented control inner segments).

### Font

No structural changes. Token names (`display`, `title`, `heading`, etc.) stay. Underlying sizes were already close to v2 spec.

### Spacing

No changes to token names or values — existing spacing tokens map well enough to the v2 8px grid.

### Motion

Update/add:
```swift
static let shimmer   = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
static let pulse     = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
static let coachmark = Animation.easeOut(duration: 0.24)
```

---

## 2 · `ReplrMark` component

New view added to `Shared/ReplrComponents.swift`:

```swift
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

---

## 3 · `ModeSegmentedControl` — text-only + Replr mark

In `ReplrKeyboard/Views/KeyboardView.swift`, `ModeSegmentedControl`:

- **Remove** SF Symbol icons (`message.fill`, `envelope.fill`) from each segment button.
- Text only: "Chat" / "Email", 13pt/500, sentence case.
- Segment height: fixed at 32pt via `.frame(height: 32)` on the outer container.
- Active segment: `surfaceRaised` fill, `textPrimary` color.
- Inactive: transparent, `textSecondary`.
- Outer container: `surface` fill, 1pt `border`, `r-sm` (8pt) outer radius, 3pt padding, 2pt inter-segment gap. Inner segments use 6pt radius (r-sm minus padding).

`KeyboardHeader` updated layout:

```swift
HStack(spacing: 0) {
    ModeSegmentedControl(model: model)
    Spacer()
    ReplrMark(size: 14)
}
.padding(.horizontal, 16)
.padding(.vertical, 8)
```

ToneRow stays below this HStack, unchanged structurally.

---

## 4 · `IdlePanelView` — chat body

In `ReplrKeyboard/Views/IdlePanelView.swift`, replace `chatContent`:

```
VStack(alignment: .leading, spacing: 12) {

    // Primary CTA — 48pt, r-sm (8pt), coral fill, sparkles leading icon
    Button {
        withAnimation(.easeInOut(duration: 0.18)) { model.isCollapsed = true }
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 14))
            Text("Capture this chat").font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(ReplrTheme.Color.onAccent)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(ReplrTheme.Color.accent)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous))
    }
    .buttonStyle(.plain)

    // Sub-caption — left-aligned, 12pt/400, textTertiary
    Text("Minimises the keyboard so you can double-tap to screenshot")
        .font(.system(size: 12))
        .foregroundColor(ReplrTheme.Color.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)

}
.padding(.horizontal, 16)
.padding(.top, 16)
.padding(.bottom, 8)
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
```

Remove the vertical `Spacer()` wrappers — content sits near the top under the header.

**Email content** — same button height (48pt) and radius (`r-sm`) treatment. Clipboard status row: change `checkmark.circle.fill` icon to `doc.on.clipboard` when ready, `doc.on.clipboard` grayed when not ready (matches design asset table).

---

## 5 · `CollapsedStripView` — capture bar

In `ReplrKeyboard/Views/KeyboardView.swift`, replace `CollapsedStripView`:

The `CollapsedStripView` is a standalone view (no header) — the keyboard collapses to ~64pt showing only the capture card. The mode segmented control is not shown while collapsed (matches `KbCaptureBar` in keyboard.jsx).

### Layout

```
ZStack(alignment: .topLeading) {
        HStack(spacing: 10) {
            TapGlyph()
            VStack(alignment: .leading, spacing: 1) {
                Text("Double-tap the back of your phone")  // 13.5pt/500, t1
                Text("to capture this chat")               // 11.5pt/400, t3
            }
            Spacer()
            Button { model.isCollapsed = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(ReplrTheme.Color.surface)
        .overlay(alignment: .leading) {
            ReplrTheme.Color.accent.frame(width: 3)   // coral left border
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ReplrTheme.Color.border, lineWidth: 1)
        )

        // Coachmark — shown once per install
        if showCoachmark {
            CoachmarkBalloon()
                .offset(y: -48)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(ReplrTheme.Color.bg)
```

### `TapGlyph` (new SwiftUI view)

```swift
struct TapGlyph: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Phone body
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ReplrTheme.Color.textSecondary, lineWidth: 1.2)
                .frame(width: 18, height: 24)
            // Inner pulse dot
            Circle()
                .fill(ReplrTheme.Color.accent)
                .frame(width: 4, height: 4)
                .opacity(pulse ? 1.0 : 0.35)
            // Outer pulse ring — delayed
            Circle()
                .stroke(ReplrTheme.Color.accent, lineWidth: 0.8)
                .frame(width: 9, height: 9)
                .opacity(pulse ? 0.4 : 0.1)
        }
        .frame(width: 22, height: 28)
        .onAppear {
            // Use withAnimation + repeatForever for SwiftUI repeating animations
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
```

### `CoachmarkBalloon` (new view)

- Coral fill (`accent`), `onAccent` text
- 12.5pt/500, padding 10×14
- Text: `"① Keyboard's minimised. ② Double-tap the back."`
- Diamond tail: `Rectangle().fill(accent).frame(width:10,height:10).rotationEffect(.degrees(45))` pinned bottom-left
- Shadow: `.shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)`
- `r-md` (12pt) radius

**`showCoachmark` state:** `CollapsedStripView` holds `@State private var showCoachmark: Bool`. Initialize in `.onAppear`:
```swift
showCoachmark = !(UserDefaults(suiteName: Constants.appGroupID)?
    .bool(forKey: "keyboard.coachmarkSeen") ?? false)
```
Dismiss (set `showCoachmark = false` + write `true` to UserDefaults) when:
- The × cancel button is tapped, OR
- The view disappears (`.onDisappear`) — covers both "replies arrived" and "cancelled" paths.

### `KeyboardViewController` height

```swift
if isCollapsed {
    self.setHeight(64)   // was 44
}
```

---

## 6 · Behaviour notes

- Reduce Motion: all `pulse` animations replaced with instant opacity swap when `UIAccessibility.isReduceMotionEnabled`.
- The `KeyboardHeader`'s `isSegmentedDisabled` and `isToneHidden` parameters continue to work as-is for loading/error states.
- No state machine changes. `KeyboardState`, `KeyboardModel`, and poll logic are untouched.
- `ElevatedSurface` modifier: the `highlight` color it references is removed; replace with `surfaceRaisedHi` or simply remove the inner highlight overlay (shadows are the elevation signal now per v2 spec which says "no shadow on in-page cards").

---

## 7 · Out of scope (later steps)

- Replies screen redesign (step 3)
- Loading skeleton redesign (step 6)
- Error state redesign (step 6)
- Coachmark animation polish (step 6)
- Companion app token updates (follow-on)
