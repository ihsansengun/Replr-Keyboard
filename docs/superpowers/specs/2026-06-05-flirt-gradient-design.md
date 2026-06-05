# Replr redesign — "Flirt Gradient" design language

**Status:** spec for review · **Date:** 2026-06-05 · **Direction chosen:** G · Flirt Gradient (adaptive light + dark)

## Decision

Replace Replr's teal/navy identity with a warm, flirty, premium language for the
**dating market**. The constant brand element is a warm **gradient (rose → coral
→ amber)**. The app stays **adaptive**: full light **and** dark, the gradient the
same in both. Hero/marketing look = **dark** (the gradient glows); light fully
supported.

Feel: flirty, warm, confident, premium — "a sharp wingman," not juvenile.

**Flexibility (not a one-way door):** every palette value lives in `ReplrTheme`
(mirrored in `DESIGN.md`). Changing the hex later re-skins the entire app — UI
**and** animations — from one place. We can try any palette anytime.

## Palette (adaptive)

**Constant brand gradient** (both modes): `#FF5E8A` → `#FF7A59` → `#FFB45E`,
linear, top-leading → bottom-trailing. Used for: primary CTA fill, active tone
chip, brand mark/avatar, the "action" elements in animations.

| Token | Dark (hero) | Light | Use |
|---|---|---|---|
| `bg` | `#15101A` | `#FFF8F5` | screen background (warm plum-black / warm white) |
| `surface` | `#211826` | `#FFFFFF` | cards, panels, rows |
| `surfaceRaised` | `#2D2032` | `#FFFFFF` (shadow) | raised cards |
| `accent` (solid) | `#FF6F91` | `#E8447A` | icons, selection, tints, borders (deeper rose on light for contrast) |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | text/icons on gradient/accent |
| `textPrimary` | `#F4E8ED` | `#2E1F28` | warm near-white / warm near-black |
| `textSecondary` | `#C7B0BC` | `#7A5A66` | |
| `textTertiary` | `#8E7886` | `#A98F99` | |
| `glassBorder` | white 10% | black 8% | hairline borders |
| `accentSoft` | rose 14% | rose 12% | subtle tints |
| `accentGlow` | rose 42% | rose 22% | shadow color on primary actions |
| `danger`/`success` | iOS system | iOS system | unchanged |

Contrast: verify rose accents/text on light meet AA (large/bold ok; use deeper
`#E8447A` for small accent text).

## Typography

Keep the SF Pro scale (display/title/heading/headline/body/callout/footnote/
caption/overline) and tracking. Confident bold display. (Optional future: a
friendlier display face — out of scope here.)

## Shape · Depth · Motion

- **Shape:** generous rounding. Primary CTAs = **full pill** (PrimaryButton is
  already a capsule). Cards = `md`(12)/`lg`(16); suggestion cards ~13.
- **Depth:** soft **rose-tinted** shadows; primary CTA = gradient fill + warm
  glow (`accentGlow`) + existing 1px inner top highlight + `ShimmerOverlay`.
- **Motion:** keep `Motion.*`; gradient shimmer sweep on the primary CTA.

## Components

- **PrimaryButton** — fill becomes the **brand gradient** (was solid accent),
  capsule, `onAccent` text, warm glow.
- **Active tone chip** — gradient fill, white text; inactive = surface + warm border.
- **Cards / brandCard** — `surface`, rounded, warm hairline border, soft warm shadow.
- **Accent (solid)** used for icons, selection, small tints where a gradient is impractical.

## Implementation scope

1. **`ReplrTheme.Color`** — swap teal palette → warm (table above), keep adaptive;
   add a `brandGradient` token (`LinearGradient`) + a gradient helper for fills.
2. **`ReplrComponents`** — PrimaryButton (+ Secondary/Tertiary), tone chips, and
   any accent-driven views use the gradient/warm accent.
3. **Lottie accent = runtime-tinted (swappable)** — the 8 embedded scenes use a
   teal accent fill. Rather than bake new colors, tint the accent at **runtime**
   via a Lottie `ColorValueProvider` reading `ReplrTheme.Color.accent`. The
   animations then re-color from the **single token** and adapt to light/dark
   automatically — any future palette change is one line, no JSON edits. (Name the
   accent fills so the value-provider keypath can target them.)
4. **`DESIGN.md`** — rewrite to the Flirt Gradient language (this spec is the source).
5. **Sweep** for hardcoded teal (e.g. `ReplrTheme._accent` hex, `accentGlow` hex,
   any view literals) → warm values.
6. **Verify** every surface — app, keyboard, onboarding/tutorial — in **light + dark**
   on device.

## Out of scope (this pass)

Custom display font · tone-name/content rewrites for dating (Flirty/Smooth/… — a
separate content task) · new iconography/illustration · the bird mark redesign ·
marketing assets.

## Risks / notes

- Gradient ≠ `Color`: components that currently fill with a `Color` accent need a
  gradient-aware path. Keep a solid `accent` for places a gradient won't work.
- Light-mode rose contrast — use the deeper `#E8447A`, verify AA.
- With Lottie runtime tinting, the whole job is essentially a **token swap** —
  views already use `ReplrTheme.*` and animations tint from the same token. The
  one-time work is wiring the value providers + the gradient-aware components.
- Keyboard extension renders SwiftUI gradients fine (no constraint there).
