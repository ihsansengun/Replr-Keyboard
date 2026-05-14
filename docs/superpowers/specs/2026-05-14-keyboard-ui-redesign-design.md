# Keyboard UI Redesign — Design Spec

## Summary

Full visual and UX redesign of the Replr keyboard extension. Replaces the current generic look with a Precision Tool aesthetic: black + amber, no gradients, zero fluff. Every pixel serves the flow.

---

## Color System

Dark-only for v1. No light mode.

| Token | Hex | Usage |
|---|---|---|
| `background` | `#111` | Keyboard body |
| `backgroundDeep` | `#0D0D0D` | Tone bar background |
| `surface` | `#161616` | Dimmed step rows, skeleton |
| `surfaceActive` | `#1A1600` | Active/amber step row fill |
| `border` | `#1E1E1E` | Hairlines, tone bar top border |
| `borderActive` | `#F5A623` | Active step left bar |
| `borderDim` | `#2A2A2A` | Dimmed step left bar |
| `amber` | `#F5A623` | Active tone chip, step numbers, dots |
| `amberText` | `#C8A060` | Active row text, chip text |
| `amberSubtle` | `#5A4820` | Chip ✕, edit link |
| `amberBg` | `#2A2000` | Active context chip fill |
| `amberBgBorder` | `#3A3010` | Active context chip border |
| `textPrimary` | `#E0E0E0` | Reply card body text |
| `textDim` | `#555` | Dimmed step text |
| `textGhost` | `#2A2A2A` | Placeholder hint text |

Update `KBColors` struct to expose these as static constants.

---

## Keyboard States

The keyboard has four states. Height animates when transitioning between idle/loading/reply.

### 1. Idle State

**Height:** ~250px

**Layout:**
```
┌─────────────────────────────────────────┐
│  [1 amber] Context        [chip ✕] or   │  ← active row (amber left bar)
│                           + Add hint…   │
│  [2 dim]   Pick a tone below            │  ← dimmed until context set
│  [3 dim]   Triple-tap back of phone     │  ← dimmed until tone selected
│─────────────────────────────────────────│
│  Casual  Dating  Pro  Bold  Friendly…   │  ← tone bar
└─────────────────────────────────────────┘
```

**Step activation logic:**
- Row 1 always active (amber) — it's the first action
- Row 2 activates (amber) once context is set OR user taps it directly (context is optional)
- Row 3 activates once a tone is selected
- All three can be in any state — user can tap any row directly

**Context row behaviour:**
- Empty: shows `+ Add hint…` in ghost text (right-aligned in row)
- Tap row → iOS system keyboard appears, user types freeform hint
- Once typed: text collapses to amber chip with ✕ (max-width truncates with ellipsis)
- Tap ✕ → clears context, row returns to empty state
- Context is ephemeral — not saved, cleared on "New"

### 2. Loading State

**Height:** same as reply state (~320px) — no height jump when replies arrive

**Layout:**
```
┌─────────────────────────────────────────┐
│  ┌───────────────────────────────────┐  │
│  │  ████████████████████             │  │  ← skeleton lines (3 lines)
│  │  ██████████████                   │  │
│  │  █████████                        │  │
│  │                      [████] [██]  │  │  ← skeleton footer
│  └───────────────────────────────────┘  │
│  ─────────────────────────────────────  │  ← back card peek
│           ● ○ ○                         │  ← dots
│─────────────────────────────────────────│
│  Casual  Dating  Pro  Bold  Friendly…   │
└─────────────────────────────────────────┘
```

Skeleton lines use `surface` (#161616), animated shimmer from left to right (opacity pulse). Same card shape and padding as the reply card.

### 3. Reply State

**Height:** ~320px

**Layout:**
```
┌─────────────────────────────────────────┐
│  ┌───────────────────────────────────┐  │
│  │  "Perfect, I'll be there at 9am.  │  │
│  │  Really looking forward to it —   │  │
│  │  let me know if anything changes."│  │
│  │                                   │  │
│  │  ← swipe for more      ✏ Edit    │  │
│  └───────────────────────────────────┘  │
│  ───────────────────────────────────    │  ← back card peek (#181818, 50% opacity)
│           ● ○ ○            ↺ New       │  ← dots + regen button
│─────────────────────────────────────────│
│  Casual  Dating  Pro  Bold  Friendly…   │
└─────────────────────────────────────────┘
```

**Swipe card behaviour:**
- 3 reply cards (free tier), swiped horizontally
- Back card always visible at bottom-right corner (offset: top +4px, left +8px, right -4px) — signals more exist
- Dots indicator: amber dot = current, grey = others
- Tap card → inserts reply into text field, stays on reply state
- Swipe left → next card, dots update
- ✏ Edit (amber) → copies reply text into the input field for manual editing
- ↺ New → clears replies, returns to idle state

**Reply persistence:**
- Replies stored in App Group UserDefaults on generation
- On keyboard open: if `persistReplies == true` AND stored replies exist → open directly in reply state
- `persistReplies` defaults to `true`, user can toggle off in Settings
- Storing: reply array + selected tone name + timestamp

### 4. Error State

**Height:** same as idle (~250px)

Simple inline text replacing the step rows:

```
┌─────────────────────────────────────────┐
│                                         │
│   Something went wrong.                 │
│   Check your connection and try again.  │
│                                         │
│─────────────────────────────────────────│
│  Casual  Dating  Pro  Bold  Friendly…   │
└─────────────────────────────────────────┘
```

Text colour: `#555`. No icons. Specific messages:
- Network fail: "No connection. Check your internet and try again."
- API error: "Couldn't generate replies. Try again."
- Empty clipboard (email tone): "Copy the email text first, then triple-tap."

Tap anywhere in error area → returns to idle state.

---

## Tone Bar

Fixed at the bottom of the keyboard, always visible in all states.

- Active tone: amber pill (`#F5A623`, text `#111`, bold)
- Inactive tones: text only, `#3A3A3A`, no background
- Scrollable horizontally (scrollbar hidden)
- Tapping inactive tone → activates it, activates row 3 in idle state

Tones (in order): Casual, Dating, Pro, Bold, Friendly, Formal, Witty, Email

---

## Transitions

| From | To | Animation |
|---|---|---|
| Idle | Loading | Height expands, step rows fade out, skeleton fades in (0.25s ease) |
| Loading | Reply | Skeleton fades out, reply card slides up (0.2s ease) |
| Reply | Idle (New tapped) | Reply card fades out, step rows fade in (0.2s ease) |
| Any | Error | Cross-fade (0.2s) |

Height changes animate with `withAnimation(.easeInOut(duration: 0.25))`.

---

## Settings Toggle

In `SettingsView`, under a "Keyboard" section:

```
Keep replies between sessions    [toggle — on by default]
When enabled, your last generated replies stay visible
the next time you open the keyboard.
```

Stored as `persistReplies` Bool in App Group UserDefaults.

---

## Out of Scope (v1)

- Light mode
- Saved/pinned contexts
- Per-conversation reply history
- Reply editing inline (✏ copies to field, user edits manually)
