---
version: alpha
name: Replr
description: >
  AI reply-suggestions app for iOS — companion app + custom keyboard +
  broadcast extensions. Adaptive (dark + light), warm and flirty, with a rose→coral→amber brand gradient and a rose accent.
  Tokens are SwiftUI/adaptive (dark + light); values below are the resolved
  hex per mode. SOURCE OF TRUTH for tokens is Shared/ReplrTheme.swift — this
  file is the lightweight, AI-facing summary. Never hardcode colors/fonts/
  spacing in views; always use ReplrTheme.* .

colors:
  # token: { dark, light }   (UIColor dynamic — see ReplrTheme.Color)
  bg:            { dark: "#15101A", light: "#FFF8F5" }   # warm plum-black / warm white
  surface:       { dark: "#211826", light: "#FFFFFF" }   # cards, panels
  surfaceRaised: { dark: "#2D2032", light: "#FFFFFF" }
  accent:        { dark: "#FF6F91", light: "#E8447A" }   # flirt rose (deeper on light)
  brandGradient: "#FF5E8A -> #FF7A59 -> #FFB45E"         # rose -> coral -> amber (both modes)
  onAccent:      "#FFFFFF"
  textPrimary:   "iOS .primary"        # semantic, adaptive
  textSecondary: "iOS .secondary"
  textTertiary:  "iOS .tertiaryLabel"
  glassBorder:   { dark: "white 10%", light: "black 8%" }
  accentSoft:    "accent @ 12%"
  accentGlow:    { dark: "accent @ 42%", light: "accent @ 22%" }   # shadow on actions
  danger:        "iOS .systemRed"
  success:       "iOS .systemGreen"

typography:
  # SF Pro (system, design: .default). Tracking applied at call site via .tracking().
  display:  { fontSize: 32, fontWeight: 700, letterSpacing: -0.5 }
  title:    { fontSize: 26, fontWeight: 700, letterSpacing: -0.4 }
  heading:  { fontSize: 20, fontWeight: 600, letterSpacing: -0.2 }
  headline: { fontSize: 17, fontWeight: 600 }
  body:     { fontSize: 17, fontWeight: 400 }
  callout:  { fontSize: 15, fontWeight: 400 }
  footnote: { fontSize: 13, fontWeight: 400 }
  caption:  { fontSize: 12, fontWeight: 500 }
  overline: { fontSize: 12, fontWeight: 600, letterSpacing: 1.5 }

rounded:
  xs: 4
  sm: 8
  md: 12
  lg: 16
  xl: 20
  full: 999

spacing:   # 4pt grid (ReplrTheme.Spacing)
  xs: 4
  sm: 8
  md: 12
  lg: 16
  xl: 20
  xxl: 24
  s3xl: 32
  s4xl: 40
  screenMarginApp: 24
  screenMarginKeyboard: 16

components:
  primaryButton:
    typography: "{typography.callout} weight 600"
    backgroundColor: "{colors.brandGradient}"
    textColor: "{colors.onAccent}"
    rounded: "{rounded.full}"      # Capsule
    height: 48
    padding: "0 22"
  secondaryButton:
    backgroundColor: "white 4%"
    textColor: "{colors.textPrimary}"
    rounded: "{rounded.full}"
    height: 48
  brandCard:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.md}"
  badge:
    backgroundColor: "{colors.accentSoft}"
    textColor: "{colors.accent}"
    typography: "{typography.overline}"
    rounded: "{rounded.full}"
---

## Overview

Replr turns a chat screenshot into ready-to-send replies. The product should
**feel calm, precise, and quietly premium** — never noisy or playful-juvenile.
Voice is **third person using the brand name "Replr"** (not first person): e.g.
"Replr reads it and drafts the replies." Copy is plain and jargon-free — avoid
internal terms ("capture", "collapse"); say what the user does ("screenshot",
"minimise").

- **Adaptive, warm.** Not dark-first anymore — full light + dark, designed and tested in both. Warm plum/white surfaces with a flirty rose→coral→amber identity.
- **Gradient is the signature.** The brand gradient (`brandGradient`) is the hero surface for the ONE primary CTA, the active/selected chip, and the brand mark. Use it sparingly — passive surfaces stay `surface`.
- **Rose is the solid accent.** Use `accent` (rose) for icons, selection, tints, and borders; `accent.opacity(…)` (`accentSoft` = 12%) to tint. Light mode uses a deeper rose (`#E8447A`) for AA contrast on white.
- **Tokens only.** Views reference `ReplrTheme.*`; never hardcode a color/font/spacing. Keeps the system swappable.

## Colors

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#15101A` | `#FFF8F5` | Screen background |
| `surface` | `#211826` | `#FFFFFF` | Cards, panels, rows |
| `surfaceRaised` | `#2D2032` | `#FFFFFF` | Raised cards |
| `brandGradient` | `#FF5E8A → #FF7A59 → #FFB45E` | same | Primary CTAs, active chips, brand mark |
| `accent` | `#FF6F91` | `#E8447A` | Solid rose — icons, selection, tints, borders |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text/icons on gradient/accent |
| `glassBorder` | white 10% | black 8% | Hairline card borders |
| `accentGlow` | accent 42% | accent 22% | Shadow color on primary actions |

- The brand **gradient** is the signature surface (primary CTAs / active chips / brand mark) — use sparingly; passive surfaces stay `surface`.
- **Rose** `accent` is the solid hue for everything else; tint with `accent.opacity(…)` (`accentSoft` = 12%).
- Light mode uses the deeper `#E8447A` for AA contrast on white.
- Status: `danger` / `success` are iOS system red/green (sparingly).

## Typography

Body & UI: system font (SF Pro), `design: .default`. Scale (size / weight / tracking):

`display` 32/700/−0.5 · `title` 26/700/−0.4 · `heading` 20/600/−0.2 ·
`headline` 17/600 · `body` 17/400 · `callout` 15/400 · `footnote` 13/400 ·
`caption` 12/500 · `overline` 12/600/+1.5 (uppercase labels).

- **Max two weights per region.** Pair a bold/semibold heading with a regular body.
- Tracking is applied at the call site: `.tracking(-0.5)` etc. (Font constants can't carry it.)
- **Serif display — onboarding / marketing headlines only.** `ReplrTheme.Font.serif(size:weight:)`
  → bundled **Fraunces** (registered at launch via Core Text; falls back to the system serif).
  Tokens: `serifDisplay` (34/bold), `serifTitle` (26/semibold). Never use serif in the keyboard
  extension or for body/UI — SF Pro only there.
- **Amber accent** `ReplrTheme.Color.amber` (#FFB45E): onboarding doodle coachmarks. For a
  highlighted word in a headline, use `accent` (rose) — amber lacks contrast on light cards.

## Layout

- **4pt spacing grid** (`ReplrTheme.Spacing`): 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 …
- Screen margins: **24** in the app, **16** in the keyboard extension (tighter).
- Rows: 12 vertical padding. Cards group related controls on a `surface` panel.
- Keyboard heights are fixed per state in `KeyboardViewController` (extensions
  can't size intrinsically) — change the constant, not the layout.

## Elevation & Depth

`ReplrTheme` modifiers — don't hand-roll shadows:

- `.elevatedSurface(.level1)` — standard card lift (soft, larger blur in light).
- `.elevatedSurface(.primaryAction)` — stronger lift + faint top glow.
- `.brandCard()` — surface + `rounded.md` + adaptive hairline border + lift.
- Primary actions also carry an **accent glow** (`accentGlow`, radius ~18).
- Depth = soft shadow + a 1px inner top highlight (white ~30%, the "kit signature").

## Shapes

- Continuous-corner rounded rects everywhere: `RoundedRectangle(cornerRadius:
  …, style: .continuous)`.
- Radius scale: `xs 4` (chips/keys) · `sm 8` (small buttons/keyboard CTA) ·
  `md 12` (cards — default) · `lg 16` / `xl 20` (large surfaces) · `full 999`
  (pills, primary buttons, tone chips).
- **Primary CTAs are capsules** (`full`); **cards are `md`**.

## Components

Lightweight summary — full implementations are the source of truth in
`Shared/ReplrComponents.swift` (open it before building/modifying these):

- **PrimaryButton** — **brand gradient** Capsule, full-width, height **48**, `callout`/600
  text in `onAccent`, white-30% inner top highlight, `accentGlow` shadow, scales
  to 0.97 on press (`Motion.quick`). The one bold CTA per screen.
- **SecondaryButton** — Capsule, `white 4%` fill, `white 18%` border, primary text.
- **TertiaryButton** — text-only (low-emphasis, e.g. "I have an account").
- **brandCard()** / cards — `surface`, `rounded.md`, hairline border, lift.
- **Badge** — small `overline` pill, `accentSoft` bg / `accent` text (use sparingly —
  it confused testers when overused on the keyboard).
- **Tone chips** — rounded pills; selected = gradient fill with `onAccent` (white) text,
  unselected = surface + border.
- **ShimmerOverlay** — moving light sweep on accent CTAs (premium cue); clipped
  to the button's corner radius.
- **Lottie animations** — embedded raw-string JSON + `LottieView`; see
  `memory/project_lottie_animations.md` for the authoring/embedding pipeline.

> Keep this section a pointer. Per-component detail (variants, sizes, anti-
> patterns) belongs next to the component, not bloating this file.

## Do's and Don'ts

**Do**
- Use `ReplrTheme.*` tokens for every color, font, radius, spacing, motion.
- Use `brandGradient` for the one primary CTA / active chip; use solid `accent` (rose) for everything else; tint with `accent.opacity(…)`.
- Design dark **and** light; verify both.
- Use `PrimaryButton` (capsule) for the one primary CTA; `brandCard()` for cards.
- Use continuous corners and the 4pt grid.
- Write copy in plain language, third-person "Replr".

**Don't**
- Hardcode hex colors, font sizes, or spacing in views.
- Apply the gradient to passive surfaces (cards stay `surface`), or invent a hue outside the rose→amber ramp.
- Use more than two font weights in one region.
- Add custom fonts.
- Use internal jargon in user-facing copy ("capture", "collapse").
- Hand-roll shadows — use `.elevatedSurface` / `.brandCard`.
