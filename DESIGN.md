---
version: alpha
name: Replr
description: >
  AI reply-suggestions app for iOS — companion app + custom keyboard +
  broadcast extensions. Dark-first, calm and precise, with one teal accent.
  Tokens are SwiftUI/adaptive (dark + light); values below are the resolved
  hex per mode. SOURCE OF TRUTH for tokens is Shared/ReplrTheme.swift — this
  file is the lightweight, AI-facing summary. Never hardcode colors/fonts/
  spacing in views; always use ReplrTheme.* .

colors:
  # token: { dark, light }   (UIColor dynamic — see ReplrTheme.Color)
  bg:            { dark: "#0D1117", light: "#F5F1EB" }   # deep navy / warm cream
  surface:       { dark: "#131929", light: "#FDFCFA" }   # cards, panels
  surfaceRaised: { dark: "#1C2539", light: "#FFFFFF" }
  accent:        { dark: "#17EAD9", light: "#009487" }   # brand teal (THE only hue)
  onAccent:      "#FFFFFF"
  textPrimary:   "iOS .primary"        # semantic, adaptive
  textSecondary: "iOS .secondary"
  textTertiary:  "iOS .tertiaryLabel"
  glassBorder:   { dark: "white 12%", light: "black 12%" }
  accentSoft:    "accent @ 12%"
  accentGlow:    { dark: "accent @ 45%", light: "accent @ 25%" }   # shadow on actions
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
    backgroundColor: "{colors.accent}"
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

- **Dark-first.** Deep-navy surfaces with one bright teal accent. Every color
  is adaptive (dark + light) — design and test both.
- **One accent.** Teal is the *only* hue. Everything else is neutral
  (navy/cream surfaces, semantic gray text). No second brand color.
- **Tokens only.** Views must reference `ReplrTheme.*`; never hardcode a color,
  font, or spacing value. This keeps the design system swappable.

## Colors

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0D1117` | `#F5F1EB` | Screen background |
| `surface` | `#131929` | `#FDFCFA` | Cards, panels, rows |
| `surfaceRaised` | `#1C2539` | `#FFFFFF` | Raised cards |
| `accent` | `#17EAD9` | `#009487` | Brand teal — CTAs, selection, highlights |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text/icons on accent |
| `text*` | iOS semantic | iOS semantic | primary / secondary / tertiary |
| `glassBorder` | white 12% | black 12% | Hairline card borders (dark) |
| `accentGlow` | accent 45% | accent 25% | Shadow color on primary actions |

- Accent is the **only** non-neutral hue. To tint, use `accent.opacity(…)`
  (`accentSoft` = 12%), never a new color.
- Light mode uses a **deeper** teal (`#009487`) for contrast on cream.
- Status: `danger` / `success` are iOS system red/green (sparingly).

## Typography

System font (SF Pro), `design: .default`. Scale (size / weight / tracking):

`display` 32/700/−0.5 · `title` 26/700/−0.4 · `heading` 20/600/−0.2 ·
`headline` 17/600 · `body` 17/400 · `callout` 15/400 · `footnote` 13/400 ·
`caption` 12/500 · `overline` 12/600/+1.5 (uppercase labels).

- **Max two weights per region.** Pair a bold/semibold heading with a regular body.
- Tracking is applied at the call site: `.tracking(-0.5)` etc. (Font constants can't carry it.)
- No custom fonts.

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

- **PrimaryButton** — accent **Capsule**, full-width, height **48**, `callout`/600
  text in `onAccent`, white-30% inner top highlight, `accentGlow` shadow, scales
  to 0.97 on press (`Motion.quick`). The one bold CTA per screen.
- **SecondaryButton** — Capsule, `white 4%` fill, `white 18%` border, primary text.
- **TertiaryButton** — text-only (low-emphasis, e.g. "I have an account").
- **brandCard()** / cards — `surface`, `rounded.md`, hairline border, lift.
- **Badge** — small `overline` pill, `accentSoft` bg / `accent` text (use sparingly —
  it confused testers when overused on the keyboard).
- **Tone chips** — rounded pills; selected = accent border/tint, unselected =
  surface + border.
- **ShimmerOverlay** — moving light sweep on accent CTAs (premium cue); clipped
  to the button's corner radius.
- **Lottie animations** — embedded raw-string JSON + `LottieView`; see
  `memory/project_lottie_animations.md` for the authoring/embedding pipeline.

> Keep this section a pointer. Per-component detail (variants, sizes, anti-
> patterns) belongs next to the component, not bloating this file.

## Do's and Don'ts

**Do**
- Use `ReplrTheme.*` tokens for every color, font, radius, spacing, motion.
- Keep teal as the single accent; tint with `accent.opacity(…)`.
- Design dark **and** light; verify both.
- Use `PrimaryButton` (capsule) for the one primary CTA; `brandCard()` for cards.
- Use continuous corners and the 4pt grid.
- Write copy in plain language, third-person "Replr".

**Don't**
- Hardcode hex colors, font sizes, or spacing in views.
- Introduce a second brand hue or a new gray.
- Use more than two font weights in one region.
- Add custom fonts.
- Use internal jargon in user-facing copy ("capture", "collapse").
- Hand-roll shadows — use `.elevatedSurface` / `.brandCard`.
