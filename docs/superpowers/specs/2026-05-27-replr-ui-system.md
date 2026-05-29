# Replr UI System — Design Spec

**Date:** 2026-05-27
**Goal:** Tighten Replr's existing UI on the brand kit at `docs/design/replr-ui-kit.html` — fix layout bugs, replace native iOS primitives with custom branded ones, and apply a strict 8pt grid + mathematical typography across every surface.

---

## Problem

Production UI has drifted from the documented brand kit:

1. Several screens reference coral `#FF5A4D` from an un-merged v2 spec proposal (`tokens.md`). The actual brand accent is **teal #17EAD9**.
2. Production layout bugs: history card text overlap, capture-detail memory header overlap, floating tab pill clipping the last settings row, "Insert reply" button text wrapping to two lines.
3. Native iOS chrome (default `Toggle`, `Picker`, segmented controls, SF Symbol chevrons) competes with the brand language.
4. Spacing drifts off any grid — paddings are arbitrary values.
5. Accent overuse: some screens have 3+ teal hits when the discipline rule is **one accent per screen**.

This spec locks the brand on the kit's actual tokens (teal, glow, pill buttons, Inter typography), defines a complete custom-primitive set, and fixes the P1 bugs.

---

## What's locked

### Brand identity — kept as-is

- **Name**: Replr
- **Wordmark**: `Replr.` — capital R + the period in teal. Inter 800 for hero/display, Inter 700 for navigation.
- **Logo mark**: existing bird-in-squircle SVG at `docs/design/Replr-logo.svg`. Used for the app icon, the in-app top header, and the keyboard chrome top-right.
- **Animated mascot dot**: **deferred** to a follow-up effort. Not in this pass.

---

## Design tokens

### Color

| Token | Value | Use |
|---|---|---|
| `bg` | `#0D1117` | Base / page background |
| `surface` | `#131929` | Cards, capture bar, reply card, sheets |
| `raised` | `#1C2539` | Secondary buttons, raised pills, recessed track for toggles |
| `raised-2` | `#283353` | Hover / active raised |
| `t1` | `#FFFFFF` | Primary text, headings, reply body |
| `t2` | `#8A96AA` | Secondary text |
| `t3` | `#4D5A6F` | Tertiary, captions, mono metadata |
| `t4` | `#2E3849` | Disabled, inactive dots |
| `teal` | `#17EAD9` | THE accent. One per screen. |
| `teal-dim` | `rgba(23,234,217,0.10)` | Tinted backgrounds (chip on, memory card bg) |
| `teal-line` | `rgba(23,234,217,0.30)` | Active borders |
| `teal-glow` | `rgba(23,234,217,0.45)` | Glow shadows |
| `violet` | `#A78BFA` | Supporting accent — used rarely (premium, avatar gradients) |
| `hair` | `rgba(255,255,255,0.07)` | Default hairlines |
| `glass` | `rgba(255,255,255,0.12)` | Active borders, glass buttons |

**Discipline rule**: maximum one teal element per screen. If two want to appear (e.g. accent on title + accent on button), demote the lesser one to neutral. Semantic teal indicators (✦ on memory-enabled contact filter chips, version mono tag) are exempt because they convey state, not emphasis.

### Typography

**Families**:
- `Inter` — display, headings, body, UI
- `JetBrains Mono` — labels, numerals, timestamps, technical metadata

**SwiftUI fallback**: if Inter / JetBrains Mono aren't bundled in the binary, use `SF Pro Display`/`SF Pro Text` and `SF Mono` — same metrics, same tracking.

| Style | Size | Weight | Tracking | Line height | Use |
|---|---|---|---|---|---|
| display | 48 | 800 | −0.040em | 1.04 | Hero / splash only |
| h1 | 32 | 800 | −0.035em | 1.08 | Screen titles ("History.", "Settings.") |
| h2 | 24 | 700 | −0.030em | 1.15 | Section titles |
| h3 | 20 | 700 | −0.025em | 1.20 | Card titles |
| body | 16 | 400 | −0.011em | 1.55 | Reply card body, summary text |
| ui | 14 | 500 | −0.006em | 1.45 | Button labels, list rows |
| caption | 12 | 500 | −0.003em | 1.40 | Helper text, sub-labels |
| label | 10.5 | 700 | +0.140em uppercase | 1.0 | Eyebrows, section headers (mono) |
| mono | 11 | 500 | +0.04em tabular | 1.0 | Counters, timestamps |

### Spacing — 4pt baseline / 8pt grid

| Token | px |
|---|---|
| `s-1` | 4 |
| `s-2` | 8 |
| `s-3` | 12 |
| `s-4` | 16 |
| `s-5` | 24 |
| `s-6` | 32 |
| `s-7` | 48 |
| `s-8` | 64 |
| `s-9` | 96 |

**Discipline rule**: every padding, margin, gap, gutter resolves to one of these nine values. Left padding always equals right padding (symmetric). Card content padding = `s-5` (24). Section gap = `s-6` (32). No arbitrary values like 14, 18, 22.

### Radii

| Token | px | Use |
|---|---|---|
| `r-1` | 4 | Status chips, small badges |
| `r-2` | 8 | Inputs, non-pill buttons, message bubbles |
| `r-3` | 12 | Cards, reply card, memory card |
| `r-4` | 16 | Sheets, splash screens |
| `r-full` | 999 | Pills — most buttons, chips, tab bar, toggle track |

### Effects

- **Primary button glow**: `box-shadow: 0 4px 18px var(--teal-glow), 0 2px 6px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.30)`
- **Toggle on glow**: `box-shadow: 0 0 14px var(--teal-glow)`
- **Active dot glow**: `box-shadow: 0 0 8px var(--teal-glow)`
- **Focus ring on input**: `box-shadow: 0 0 0 3px var(--teal-dim)` + `border-color: var(--teal)`
- **Floating tab pill**: `backdrop-filter: blur(20px)` + `box-shadow: 0 8px 24px rgba(0,0,0,0.5), 0 0 24px rgba(23,234,217,0.08)`
- **Hero radial wash**: `radial-gradient(ellipse 70% 55% at 50% 0%, rgba(23,234,217,0.10), transparent 70%)` — used at the top of hero screens

In SwiftUI, glows are achieved with `.shadow(color:radius:y:)` chained, and inset highlights with a top-aligned `RoundedRectangle` overlay at 1px / `0.06` white.

---

## Custom primitives (zero iOS defaults)

Every native iOS UI element is replaced with a custom branded equivalent. The bar: **no `UISwitch`, no default segmented control, no `UISlider`, no SF Symbol chevrons in UI affordances, no system `Picker`, no default `NavigationBar` chrome, no default tab bar.**

### `BrandButton`

| Variant | Background | Text | Border | Height |
|---|---|---|---|---|
| `.primary` | `teal` + glow | `bg` (`#0D1117`) | — | 44pt |
| `.secondary` | `raised` 4% white fill | `t1` | `glass` 1pt | 44pt |
| `.ghost` | transparent | `teal` | `teal-line` 1pt | 40pt |
| `.text` | transparent | `t2` (hover `t1`) | — | auto |
| `.icon` | `raised` 4% fill | `t1` | `glass` 1pt | 44 × 44pt |

Sizes: `.sm` (36pt), `.md` (44pt, default), `.lg` (52pt). All non-text variants have pill radius (`r-full`).

### `BrandToggle` — replaces `UISwitch`

- 48 × 28pt pill track
- 20pt thumb (white when OFF, `bg`-color when ON)
- OFF: `raised` track, hair border
- ON: `teal` track + glow

### `BrandSegmented` — replaces `UISegmentedControl`

- Pill track at 40pt height
- 4pt inner padding
- Active pill: `raised` fill with inset 1px highlight + 1px bottom shadow
- Inactive: transparent

### `BrandCheck` / `BrandRadio` — replaces `Toggle` (checkbox style) / `Picker`

- 22 × 22pt
- Check: `r-1` (4pt) square; Radio: circle
- OFF: 4% white fill, 1.5pt glass border
- ON: teal fill + glow, white check / inner teal dot

### `BrandSlider` — replaces `Slider`

- 4pt track height (`raised`)
- 20pt thumb (white with glass border, 0 2px 6px shadow)
- Fill from start to thumb in teal + glow

### `BrandInput` — replaces `TextField` styling

- 48pt height
- `r-2` (8pt) radius
- 4% white fill
- 1pt glass border
- Focus: teal border + 3pt teal-dim outer halo

### `BrandChip`

- 32pt pill height (`r-full`), 0 / 14pt padding
- OFF: 4% white fill, t2 text, glass border
- ON: `teal-dim` fill, `teal` text, `teal-line` border, inset 0 0 12px teal-glow

### `BrandDots` — carousel indicator (replaces UIPageControl)

- Inactive: 5 × 5pt `t4` circles
- Active: 16 × 5pt pill in `teal` with `0 0 8px teal-glow`
- 5pt gap between dots
- Smooth width animation on selection change

### `BrandStatusBar` — replaces iOS status bar in mockups / capture mode

- JetBrains Mono 11/700, +0.06em tracking for clock
- Custom signal: 4 ascending rectangles (3pt wide, heights 5/7/9/11pt, 1pt gap)
- Custom WiFi: 1.5pt rounded outline glyph (12 × 8pt)
- Custom battery: 1pt rounded rectangle 22 × 10pt with inner fill bar
- All in `t1` (`#FFFFFF`)

### `BrandMessageBubble` — replaces iMessage-look bubbles in keyboard chat preview

- `r-2` (8pt) radius (not iMessage's 18pt)
- 1pt hair border
- 2pt accent-color side stripe — `t3` on left (them) / `teal` on right (you)
- Them: `raised` fill
- You: `teal-dim` fill, `teal-line` border

### `BrandTabPill` — replaces `TabView` chrome

- Floating, 24pt from home indicator
- `r-full` container with 5pt padding, glass border, `bg` 92% opacity, `blur(20px)`
- Inactive pill: transparent, `t2` icon + label
- Active pill: `teal-dim` fill, `teal` icon + label, `teal-line` border, inset glow

---

## Screen-by-screen treatments

### Keyboard — eight states

1. **Idle · Chat mode**: `BrandSegmented` (Chat / Email) + bird mark + "Replr." wordmark in top row. `BrandButton.primary` "Capture this chat" with leading bird-mark dot. Caption "Minimises so you can double-tap the back." `BrandChip` tone row (Casual / Friendly / Direct / Witty / Pro).
2. **Idle · Email mode**: Same shell. Primary becomes "Generate from clipboard" — disabled until clipboard contains text. Clipboard status row (mono char count when ready).
3. **Capture bar (collapsed)**: ~64pt strip. 2pt teal left border, animated phone-glyph pulse, instruction line + sub-line (caption), `BrandButton.icon` × close.
4. **Loading**: Contact row (avatar + name + position dots). Skeleton reply card matching real card dimensions exactly (no layout jump on content arrival). Status line "Reading the conversation" + 3 pulsing teal dots.
5. **Replies (hero)**: Contact row — 22pt avatar (teal-violet gradient) + name in `t1` + edit pencil + `BrandDots` position on right. Reply card 14pt padding + 16pt body. Primary "Insert reply" (38pt full-width) + secondary "Edit" (72pt). `BrandChip` tone row + refresh icon button.
6. **Edit reply**: Back chevron + "Back to replies" + contact avatar right. Editable card with teal animated caret + char count mono right-aligned. Primary "Insert reply" + secondary "Cancel".
7. **Rename contact / disambiguate**: "Who is this with?" header + close. List of candidate rows (avatar + name + teal ✓ on active). Dashed footer "+ Use a different name…" to open input sheet.
8. **Error**: Centered 40pt teal-tinted circle with custom warning glyph (1.5pt stroke), message in 14.5/500/`t1`, hint 12.5/`t3`, ghost-style "Try again" button with refresh glyph.

### Companion app — two tabs

1. **History — empty**: Top row (wordmark center, version mono right). H1 "History." + caption "No captures yet." Center stage: 56pt rounded-square icon (camera glyph), title 18/600, lede 14/`t3` (max 280pt wide). Ghost "Try a sample capture" button below.
2. **History — populated**: Top row (wordmark + "Clear all" outlined neutral). H1 "History." + sub "2,418 replies · since January" (sentence case, not tracked uppercase). Filter chip row — `BrandChip` with leading ✦ on memory-enabled contacts. Symmetric card grid: 36pt avatar (teal-violet gradient by contact-hash, letter in teal) + (name + memory ✦ + time on one row + 2-line summary below) + chevron. **Resolves the overlap bug.**
3. **Capture detail**: Custom nav row (back chevron + timestamp mono + contact avatar). Stacked sections with `s-6` gaps: Screenshot card (with `EXHIBIT · time` mono label bottom-right), Conversation summary (card body), Generated replies (3 rows: Roman numeral mono + body + copy glyph), Memory card. **Memory card resolves the header-overlap bug** — header lives inside the card: "✦ Memory · Maya" left, "UPDATED JUST NOW" mono right, body below, Edit + Forget action buttons inline.
4. **Memory editor (sheet)**: Bottom sheet over dimmed capture detail. × close + "Memory · Maya" + Save (teal pill 32pt). Ruled-paper textarea (`r-1` radius, inset shadow), mono char count `216 / 400 characters · ideal under 400`, "Reset to AI suggestion" ghost button.
5. **Settings**: Top row + H1 "Settings.". Section eyebrows in mono with leading ✦ ("✦ Keyboard", "✦ Memory", "✦ Model", "✦ Privacy", "✦ Account"). Each section wrapped in `BrandCard` — `surface` fill, hair border, `r-3` radius, internal rows separated by hair. Rows use `BrandToggle`, `BrandRadio`, mono value chip. Bottom inset of `s-9 + s-7 = 110pt` so the floating tab pill never clips the last row. **Resolves the pill-clipping bug.**

---

## P1 bugs (ship first)

1. **History card text overlap** — refactor card layout from absolute positioning to flex row. Name + time on one line, summary below. Test at all dynamic type sizes (xSmall → AX1).
2. **Capture detail memory header overlap** — move header inside the memory card on a flex row. Shorten to "✦ Memory · {Name}" left, "UPDATED {when}" mono right.
3. **Settings tab pill clipping** — add 110pt bottom inset (`safeAreaInset(edge: .bottom)` or `Spacer().frame(height: 110)`) to the scroll content.
4. **"Insert reply" wraps to two lines** — tighten icon to 10pt, ensure label fits on single line at all dynamic type sizes ≤ XL. Increase button height to 38pt.

---

## Out of scope

- **Animated mascot dot system** (12 behaviors designed; deferred to a follow-up effort)
- **Onboarding flow redesign** (separate spec — only blocked-state bugs touched here)
- **Email-mode keyboard polish** (clipboard sniffing, email-specific tones)
- **Sample-capture trigger** (empty-state CTA stub — real functionality later)
- **Logo redesign** (bird stays as-is)

---

## Files affected

| File | Change |
|---|---|
| `Shared/ReplrTheme.swift` | Lock token values to brand kit. Replace any coral references with teal. Add spacing tokens `s-1..s-9`, radii, effects. |
| `Shared/ReplrComponents.swift` | Add `BrandButton`, `BrandToggle`, `BrandSegmented`, `BrandCheck`, `BrandRadio`, `BrandSlider`, `BrandInput`, `BrandChip`, `BrandDots`, `BrandStatusBar`, `BrandMessageBubble`, `BrandTabPill`, `BrandCard`. |
| `Replr/Replr/Features/Captures/CaptureLogView.swift` | Fix history card overlap bug; redesign card to symmetric flex grid; replace thumbnails with letter-avatars; replace `Toggle`/buttons with brand primitives. |
| `Replr/Replr/Features/Memory/...` | Fix capture-detail memory header overlap (header inside the card); apply `BrandCard` to memory block; replace action buttons. |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Wrap each section in `BrandCard`; add 110pt bottom inset; replace every native `Toggle`/`Picker`/segmented with brand equivalents; "Clear all memory" → row with title in `t1` + "Clear…" trailing action in teal that opens confirm dialog. |
| `Replr/Replr/App/CustomTabBar.swift` | Update to `BrandTabPill` style — floating, teal-glow active. |
| `Replr/Replr/App/ReplrApp.swift` | Wire brand appearance — remove any default `UINavigationBar` styling that uses old teal `#0DB5A4`; use `#17EAD9`. |
| `ReplrKeyboard/Views/KeyboardView.swift` | Apply primitives across all keyboard states. Fix "Insert reply" wrap. Add `BrandDots` carousel indicator. Use `BrandMessageBubble` if we ever render preview bubbles (chat header strip already uses brand styling). |
| `Replr/Replr/Replr/Features/Tones/TonesView.swift` | Replace `List` styling and `Toggle` with `BrandChip` + `BrandToggle`. |

---

## Implementation order

1. **Foundation** — update `ReplrTheme.swift` tokens (colors, spacing, type, radii, effects). Everything else depends on this.
2. **Primitives** — build `BrandButton`, `BrandToggle`, `BrandSegmented`, `BrandChip`, `BrandDots`, `BrandCard`, `BrandTabPill` in `ReplrComponents.swift`. Snapshot-test at small / medium / large dynamic type.
3. **P1 bug fixes** — four production bugs, in order: History overlap → Memory header overlap → Settings pill clipping → Insert reply wrap.
4. **Settings screen** — apply `BrandCard` grouping, replace every native control.
5. **History + Capture Detail screens** — apply card layout + primitives.
6. **Keyboard states** — apply primitives across all eight states.
7. **Tab bar** — switch `CustomTabBar` to `BrandTabPill` style.

Steps 1–3 (foundation + primitives + P1 bugs) ship as one PR. Steps 4–7 ship as a second PR.

---

End of spec.
