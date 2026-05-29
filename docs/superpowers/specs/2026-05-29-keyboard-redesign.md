# Keyboard Redesign — Design Spec
**Date:** 2026-05-29  
**Scope:** ReplrKeyboard extension — visual identity, layout, and one new feature (Try Again)  
**Status:** Approved for implementation planning

---

## 1. Problem

The current keyboard design reads as an AI product dashboard — electric teal/blue accent, neon glow shadows, glassy blend modes, shimmer overlays. This aesthetic is misaligned with what Replr actually is: a tool that lives inside the most personal digital space (your keyboard) and helps you communicate better with people you care about. The design should feel like the app's *context* (human conversation) not its *technology* (AI).

---

## 2. Design Direction: Warm Human

Derived from the app's core purpose: helping you find the right words for the people in your life.

**Reference mood:** Day One, Bear, well-designed notebook apps. Personal, unhurried, trustworthy.  
**Not:** SaaS dashboards, AI products, developer tools.

---

## 3. Design System

### 3.1 Architecture constraint
All identity tokens live in a **single swappable file** (`Shared/ReplrTheme.swift`). Views reference semantic tokens only — never raw hex values, point sizes, or hardcoded colors. Changing the entire keyboard identity must be a single-file change.

```swift
// Every view uses:
ReplrTheme.Colors.accent
ReplrTheme.Colors.background
ReplrTheme.Typography.body

// Never:
Color(hex: "#C97B2E")
Font.system(size: 14)
```

### 3.2 Color tokens — Light mode

| Token | Value | Usage |
|---|---|---|
| `background` | `#F7F2E8` | Keyboard background |
| `surface` | `#FDFAF3` | Card / bubble backgrounds |
| `surface2` | `#F0EAD8` | Segmented control, unselected chips, secondary buttons |
| `accent` | `#C97B2E` | Primary CTA, selected bubble, active tone chip |
| `accentSubtle` | `#F5E4CC` | Selected bubble background, active chip fill |
| `accentBorder` | `rgba(201,123,46,0.40)` | Selected card/bubble border |
| `textPrimary` | `#2B1F0E` | Body text, active segment |
| `textSecondary` | `#8C7050` | Labels, contact name, secondary icons |
| `textTertiary` | `#B8A08A` | Counts, placeholders, muted labels |
| `border` | `rgba(160,112,56,0.18)` | Card borders, dividers |
| `shadow` | `rgba(43,31,14,0.10)` | Ambient shadows (no neon glow) |

### 3.3 Color tokens — Dark mode

| Token | Value |
|---|---|
| `background` | `#1C1A14` |
| `surface` | `#252219` |
| `surface2` | `#302C21` |
| `accent` | `#D4883C` |
| `accentSubtle` | `#3A2A14` |
| `textPrimary` | `#EDE5D0` |
| `textSecondary` | `#A08860` |
| `textTertiary` | `#6B5840` |
| `border` | `rgba(160,112,56,0.18)` |

### 3.4 Typography

| Role | Font | Weight | Size |
|---|---|---|---|
| Button labels, chips, segment | SF Pro Rounded | Semibold/Bold | 11–14pt |
| Reply bubble content | SF Pro Text | Regular | 11–12pt |
| Contact name, section labels | SF Pro Text | Semibold | 10–12pt |
| Tertiary labels, counts | SF Pro Text | Semibold | 9.5–10.5pt |

### 3.5 Shape & shadow

- Corner radius: `12pt` (cards/keyboard frame), `8pt` (buttons/bubble bg), `100pt` (pills/chips)
- Shadows: warm-tinted, no neon glow. Max `blur: 14pt, opacity: 0.13`
- No shimmer overlays on buttons. No glassy blend modes.
- Skeleton shimmer uses warm sand gradient (`#EDE5D0 → #F5EDD8`) not neutral gray.

---

## 4. Header Layout

**Decision: Compact single-row (Option B)**

```
[ Chat | Email ]          [ Casual ▾ ]
```

The mode segmented control and active tone sit on one row. The tone pill shows the currently selected tone with a chevron — tap to expand the full tone chip row (slides in below the segment row, then collapses after selection).

**Previous approach removed:** The always-visible scrollable tone chip row is replaced by this compact pill. The tone row only appears when the user explicitly taps the tone pill.

### Header specs
- Total header height: `42pt`
- Segmented control: warm charcoal background when active (`textPrimary`), `surface2` track
- Tone pill: `accentSubtle` background, `accent` text, `10.5pt` SF Pro Rounded Bold, chevron `▾`
- Border bottom: `0.5pt` solid `border` color

---

## 5. Reply Area

### 5.1 Format: Chat Bubbles

Replies are displayed as **right-aligned message bubbles** — the same visual language as the chat app the keyboard is sitting on top of.

**Rationale:** The user is previewing what their sent message will look like. Bubbles make this immediately obvious. This is something no other keyboard tool does.

### 5.2 Bubble specs

- Alignment: right-aligned, `max-width: 86%` of container
- Shape: `border-radius: 16 16 4 16` (standard chat bubble, flat bottom-right)
- Unselected: `surface` background, `border` stroke, `textPrimary` text
- **Selected: `accent` background, white text, `shadow` glow `rgba(201,123,46,0.35)`**
- Number label: small tertiary text (`9.5pt`) to the left of each bubble — reference only, not primary
- Tap to select — amber transition `0.15s easeInOut`

### 5.3 Scroll container

- **Fixed keyboard height for replies state: `320pt`** (previously dynamic)
- Header, contact row, and action row are pinned (non-scrolling)
- Bubble area is a `UIScrollView` / SwiftUI `ScrollView` between contact row and action row
- Bottom fade gradient: always present (`background → transparent`, `36pt`)
- Top fade gradient: appears after first scroll down
- **"↓ scroll for more" pill**: appears only when reply count overflows the visible area. Small, dark-translucent pill (`rgba(43,31,14,0.55)`), bottom-right corner, disappears after first scroll
- Scroll indicators hidden (`.scrollIndicators(.hidden)`)

### 5.4 Reply count by tier

| Tier | Reply count |
|---|---|
| Free | 3 |
| Premium | 5 (current) → extensible |
| Future tiers | Render whatever the API returns — no layout changes needed |

The bubble list renders however many replies the API returns. No hardcoded count assumptions in the view layer.

### 5.5 Contact row

Sits between header and scroll area. Pinned (non-scrolling).

```
[person icon]  You → Sarah                    [✏ pencil]
```

- `10pt` SF Pro Semibold, `textTertiary` color, uppercase, `0.07em` letter-spacing
- Pencil icon: opens contact disambiguate/rename flow (unchanged behaviour)
- No reply counter (`1 of 3`) — not needed with scrollable bubbles

---

## 6. Action Row

**Decision: Compact single row, Option A — 38pt tall**

```
[→ Insert ··········] [✏] [↺✦]
```

| Element | Spec |
|---|---|
| **Insert** | `flex: 1`, `38pt` height, `accent` background, white text, `100pt` radius pill, `0 2pt 8pt rgba(201,123,46,0.28)` shadow, SF Pro Rounded Bold 12pt |
| **Edit** | `38×38pt` square, `10pt` radius, `surface2` bg, `border` stroke, pen nib icon |
| **Try Again** | `38×38pt` square, `10pt` radius, `surface2` bg, `border` stroke, arc+sparkle icon |

### Icons (custom SVG, not SF Symbols)

**Insert** (`arrow-into-cursor`): Right-pointing arrow entering a vertical cursor line. Communicates "inject into text field."

**Edit** (`pen-nib`): Clean pen nib outline, `1.8pt` stroke, rounded caps.

**Try Again** (`arc-sparkle`): Two curved arrows forming a partial loop, 4-point star in the centre. Signals "same context, new ideas" — not a generic reload.

All icons: `15×15pt` render size, `textSecondary` stroke color on secondary buttons, white on Insert.

---

## 7. Try Again — New Feature

**This feature does not exist yet. It must be built.**

### Behaviour
Tapping Try Again fires a new API call using the **same captured screenshot already in the App Group** — no re-capture, no returning to idle. The user stays in context.

### User flow
1. User sees 3 (or N) replies and dislikes all of them
2. Taps Try Again (arc+sparkle icon)
3. Keyboard transitions to loading state
4. Loading state shows toast: **"Getting fresh replies…"** + subtitle **"Same capture · new suggestions"**
5. New replies appear as bubbles

### What changes from current "Regenerate"

| Current Regenerate | New Try Again |
|---|---|
| Clears screenshot from App Group | **Keeps** screenshot in App Group |
| Clears contact selection | Keeps contact selection |
| Returns to idle state | Stays in loading state |
| Requires full re-capture | No re-capture |

### Implementation requirement

**App Group — screenshot lifetime:**  
`AppGroupService` must **not** delete `screenshot.png` after `saveReplies()` completes. The file persists until the user starts a new capture (collapses keyboard → triple-tap back), at which point the new screenshot overwrites it.

**Trigger mechanism:**  
The keyboard extension cannot call async APIs directly. Try Again follows the same cross-process pattern as the initial capture:
1. Keyboard writes a `Constants.retryRequestKey` flag to App Group (`UserDefaults`)
2. Keyboard transitions to `.loading` state and starts the poll loop (`startCapturePoll()`)
3. `GenerateReplyIntent` is triggered (via Back Tap or a dedicated `RetryRepliesIntent` AppIntent)
4. Intent reads `screenshot.png` from the App Group container directly — no new screenshot needed
5. Intent calls `ReplyService.shared.generateReplies()` with the existing image data
6. Results written back via `AppGroupService.shared.saveReplies()` — keyboard poll picks them up

A `RetryRepliesIntent` AppIntent is the preferred approach over reusing `GenerateReplyIntent` — it keeps the two code paths cleanly separated and avoids "is this a new capture or a retry?" logic inside the intent.

**Label disambiguation:**  
The action row button is labelled **"Try Again"** (same capture, new suggestions).  
The error-state retry button retains its existing label **"Try again"** (re-attempt failed generation).  
These are different actions — do not merge them.

---

## 8. Loading State

- Skeleton cards use warm sand shimmer (`#EDE5D0 → #F5EDD8`), not neutral gray
- First-time load label: **"Generating replies…"**
- Try Again load label: **"Getting fresh replies…"** + subtitle **"Same capture · new suggestions"**
- Header dimmed to `40%` opacity during loading (non-interactive)
- Keyboard height: `280pt` (unchanged)

---

## 9. States Not Redesigned (Token Refresh Only)

The following states require no UX changes — apply the new design system tokens and remove old glow/glass effects:

| State | Change |
|---|---|
| **Idle (Chat)** | Capture card uses `surface` bg, `border` stroke, amber badge. Button uses `accent` bg, warm shadow. No shimmer overlay. |
| **Idle (Email)** | Same token refresh — amber for enabled state. |
| **Error** | Warning icon in `accent` color. "Try again" button uses standard `accent` pill style. |
| **Collapsed** | Coachmark balloon uses `accent` background instead of current blue. Handle pill uses `textTertiary`. |
| **Disambiguate** | Contact list items use `surface` cards, `border` dividers. |

---

## 10. Removed Patterns

These patterns from the current design are **explicitly removed**:

- `accentGlow` shadow (neon-colored drop shadow on buttons)
- Shimmer overlay on primary buttons (`ShimmerOverlay` view)
- `glassBorder` (white opacity blend mode borders)
- Dynamic keyboard height based on reply count (replaced by fixed `320pt` + scroll)
- Always-visible tone chip row in header (replaced by compact tone pill)
- `arrows.clockwise` SF Symbol for regenerate (replaced by custom arc+sparkle icon)

---

## 11. Open Decisions (Post-Testing)

The following were intentionally deferred — user will validate during testing:

- **Exact reply count per tier** — Free: 3 confirmed. Premium upper bound TBD.
- **Tone row expand animation** — slide-down vs fade-in when tone pill is tapped.
- **Collapsed state height** — `90pt` post-coachmark unchanged pending testing.
- **Memory banner** (sparkles + "Remembering your last chat with [Name]") — inherits token refresh, no UX change planned yet.

---

## 12. Files Affected

| File | Change |
|---|---|
| `Shared/ReplrTheme.swift` | **Rewrite** — new token architecture, Warm Human values |
| `ReplrKeyboard/Views/KeyboardView.swift` | All states updated — tokens, bubble format, header layout |
| `ReplrKeyboard/Views/ReplyBubbleView.swift` | **New file** — chat bubble component replacing reply card |
| `ReplrKeyboard/KeyboardViewController.swift` | Fixed `320pt` height for replies state, remove dynamic height logic |
| `Shared/AppGroupService.swift` | Persist `screenshot.png` after save — do not delete on `saveReplies()` |
| `Replr/Intents/RetryRepliesIntent.swift` | **New file** — AppIntent for Try Again, reads existing `screenshot.png` from App Group |
| `Shared/Constants.swift` | Add `retryRequestKey` App Group flag |
