# Replr v2 — Design tokens

Exact values for every visual token used in the design. Source of truth for the Swift implementation.

---

## Surfaces (dark)

| Token | Hex | Use |
|---|---|---|
| `base` | `#0A0A0B` | Keyboard background, app background |
| `surface` | `#131318` | Cards, capture bar, reply card, capture detail blocks |
| `raised` | `#1E1E25` | Selected segment, secondary buttons, raised pills |
| `raised-hi` | `#2A2A33` | Hover/active raised states |
| `border` | `rgba(255,255,255,0.07)` | Default hairlines |
| `border-strong` | `rgba(255,255,255,0.12)` | Active card borders, focused inputs |

## Text

| Token | Hex | Use |
|---|---|---|
| `t1` | `#F4F4F2` | Primary text, headings, reply body |
| `t2` | `#8E8E92` | Secondary text, captions |
| `t3` | `#5C5C60` | Tertiary text, monospace metadata |
| `t4` | `#3D3D42` | Disabled, chevrons |

## Accent (the only non‑neutral color)

| Token | Hex | Use |
|---|---|---|
| `accent` | `#FF5A4D` | The one primary action + selected states only |
| `accent-dim` | `#B43E35` | Hover on accent |
| `accent-soft` | `rgba(255,90,77,0.12)` | Tinted backgrounds (memory card, error glyph bg, capture detail memory section) |
| `accent-text` | `#1A0707` | Text **on** accent fills (dark) |

Alternate accents exposed in the design system as Tweaks:
* **Amber** `#F5C24E` (matches the live build's current amber if you prefer continuity)
* **Lime** `#BEF264`
* **Iris** `#A78BFA`

**Discipline rule**: maximum one coral element per screen. If a second wants to appear, demote the lesser one to neutral.

## Semantic

| Token | Hex | Use |
|---|---|---|
| `success` | `#4ADE80` | "Email ready" indicator, sent confirmations |
| `warning` | `#F5C24E` | Reserved (not actively used) |

---

## Typography

**Family**: Geist (designed in). If Geist isn't shippable in the binary, **SF Pro Rounded** is the closest substitute and renders nearly identically with the same tracking. Geist Mono → SF Mono.

| Style | Size | Weight | Tracking | Line height | Use |
|---|---|---|---|---|---|
| Display L | 46 | 600 | −0.030em | 1.02 | Hero (system overview only) |
| Display | 32–34 | 600 | −0.028em | 1.05 | Onboarding titles, app headers |
| Title | 18–20 | 600 | −0.020em | 1.1 | Section titles, history group labels |
| Subtitle | 16 | 500 | −0.015em | 1.4 | Reply body (hero text on the keyboard) |
| Body | 14.5 | 400 | −0.005em | 1.45 | History card body, capture detail body |
| Body S | 13.5 | 500 | −0.005em | 1.4 | Buttons, contact names, list rows |
| Caption | 12.5 | 400 | −0.005em | 1.45 | Subcaptions, hints, helper text |
| Label | 11–12 | 500 | −0.005em | 1.0 | Eyebrows, group headers |
| Mono | 11 | 400 | −0.005em (tabular) | 1.0 | Timestamps, counters, technical bits |

Sentence case everywhere. Contact names: capitalised properly. No ALL CAPS except the H1 ‑level "Title." style where a period is part of the brand voice.

---

## Spacing (8px grid)

| Token | px | Use |
|---|---|---|
| `s1` | 4 | Icon gap, tight inline padding |
| `s2` | 8 | Default control gap, button vertical |
| `s3` | 12 | Group gap inside a card |
| `s4` | 16 | Panel margin (keyboard, narrow), card padding |
| `s5` | 24 | Panel margin (app), gutter between sections |
| `s6` | 32 | Major section gap |
| `s7` | 48 | Bottom safe area padding |
| `s8` | 64 | Reserved |

Onboarding standard: 24pt horizontal padding, 40pt above title, 32pt before content, 40pt above footer.

---

## Radii

| Token | px | Use |
|---|---|---|
| `r-xs` | 4 | Small swatches, segmented control inner segments |
| `r-sm` | 8 | Buttons, chips, list rows |
| `r-md` | 12 | Cards, reply card, memory card |
| `r-lg` | 16 | Sheets (Memory editor, tagging) |
| `r-xl` | 20 | Reserved |

Avatars and dots = circular. Tone chips and the floating tab bar = full pill (999).

---

## Shadows

* **Floating tab bar**: `0 8px 24px rgba(0,0,0,0.4)`
* **Coachmark**: `0 8px 24px rgba(0,0,0,0.5)`
* **Memory editor sheet**: `0 -16px 40px rgba(0,0,0,0.4)`
* Reply card and other in‑page cards: **no shadow**. Hairline border only. Shadows are a spotlight, used sparingly.

---

## Heights

| Element | pt |
|---|---|
| Primary button | 48 |
| Secondary button | 48 |
| Segmented control | 32 |
| Tone chip | 28 |
| Compact tone chip (`Friendly ⌄`) | 28 |
| Tab pill | 44 |
| List row | 56 |
| Reply card | min 96, content‑driven |
| Capture bar (collapsed kb) | ~64 |
| Status bar | 56 (iOS standard, not designed) |
| Home indicator clearance | 28 |

---

## Motion

| Action | Duration | Easing |
|---|---|---|
| State transitions | 220ms | ease‑out |
| Toggle thumb | 180ms | ease‑in‑out |
| Card slide (carousel) | 240ms | ease‑out |
| Shimmer | 1400ms | linear, infinite |
| Pulse (capture glyph, accent dots) | 1000–1200ms | ease‑in‑out, infinite |
| Coachmark fade | 240ms | ease‑out |

All motion must respect Reduce Motion.

---

## Border weights

* Standard hairline: **1pt** (in SwiftUI use `0.5pt` ÷ `displayScale` for true hairline on retina, or 1pt for visual parity)
* Coral left border on capture bar: **3pt**
* Bottom indicator on tab pill: not used (the pill's background does the work)

---

## Component‑specific tokens

### Reply card
* Background: `surface`
* Border: 1pt `border`
* Radius: 12
* Padding: 18 top / 14 bottom / 16 left/right
* Body type: Subtitle (16/500/−0.011em/1.4)
* Dots: 5pt circles, active = 14×5 pill in `accent`

### Memory card (in Capture Detail)
* Background: `accent-soft`
* Border: 1pt `accent`
* Radius: 12
* Padding: 16
* Body type: Body (14.5/400/−0.005em/1.55)
* Buttons inside: `base` fill + `border-strong` border for Edit; transparent + `border` for Forget

### Capture bar (collapsed)
* Background: `surface`
* Left border: 3pt `accent`
* Other borders: 1pt `border`
* Radius: 8
* Inner padding: 10 vertical, 12 horizontal
* Min height: 44

### Tab pill (floating)
* Outer container: `surface` fill, 1pt `border`, 6pt padding, 999 radius
* Active pill: `raised` fill, coral icon + text
* Inactive pill: transparent, t2 icon + text
* Each pill: 10pt vertical / 18pt horizontal padding, 8pt gap between icon and label

---

End of tokens.
