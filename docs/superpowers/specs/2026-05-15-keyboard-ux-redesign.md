# Replr Keyboard UX Redesign

**Date:** 2026-05-15  
**Status:** Approved  
**Scope:** Keyboard extension UX — idle state, capture flow, loading/error states, reply cards

---

## Problem

General messaging users don't understand what to do when they first open the Replr keyboard. The core issues:

1. `Screenshot → triple-tap` in the idle state is cryptic — new users have no idea what action to take
2. The path to optimal capture (collapse keyboard first for bigger screenshot area) is not discoverable — the ▾ chevron is invisible as a CTA
3. The keyboard shrinks to 50px during loading, causing a jarring layout jump
4. Error state also shrinks, with no retry action
5. Reply cards have no visible send affordance — tapping the card inserts the reply but nothing communicates this

---

## Design

### 1. Idle State — Smart Action Bar

The row above the tone pills becomes a **smart action bar** that adapts per state. The QWERTY keys never move or resize.

**Before:** `Screenshot → triple-tap  ▾`  
**After:** `[Alex]  [↓ Capture replies]  [Casual ▾]`

- **Left:** Contact name in amber (tappable to edit — existing behaviour)
- **Centre:** `↓ Capture replies` button (amber, rounded) — tapping it immediately collapses the keyboard to the capture-ready strip
- **Right:** Current tone shortcut pill (tappable to open tone picker)

When tapped, the button collapses to the existing `.collapsed` state which already shows `Triple-tap the back of your phone to generate` — so no text change needed in that state, just making the collapse action discoverable.

The ▾ chevron remains for users who already know the flow.

**New user first-open (no sessions in App Group):**  
Action bar centre shows: `Set up triple-tap to get started →`  
Tapping it opens the companion app via `replr://setup` URL scheme, which navigates to an onboarding setup screen with step-by-step BackTap instructions and an "Open Settings" button (opens Settings root — no private API used).  
Once any capture session is saved, this hint is replaced by the `↓ Capture replies` button permanently.

---

### 2. Loading State

**Before:** Keyboard shrinks to `50px`, `LoadingView` shown full-screen  
**After:** Keyboard stays at `280px`. Action bar becomes:

```
[⠋  Generating…  ────────────────────]
```

- Spinner (`.medium` style) on the left
- `Generating…` label
- Thin amber progress bar animates right-to-left across the bottom of the action bar (indeterminate)
- Tone pills row remains visible below
- QWERTY keys remain visible — user can type or switch keyboard while waiting

**Implementation:** Remove `newHeight = 50` for `.loading` case in `stateCancellable` sink. Replace `LoadingView` usage with action bar content swap.

---

### 3. Error State

**Before:** Keyboard shrinks to `220px`, error message shown  
**After:** Keyboard stays at `280px`. Action bar becomes:

```
[⚠  Failed to generate   ↺ Retry]
```

- Warning icon + message left
- `↺ Retry` tappable right — re-reads cached screenshot from App Group and fires a new request
- Keys stay visible

**Implementation:** Remove `default: newHeight = 220` for error state. Add retry action to `KeyboardModel`.

---

### 4. Reply Cards — Send Affordance

**Before:** Whole card is tappable to insert reply. No visible affordance.  
**After:** Two micro-buttons in the card footer:

```
┌─────────────────────────────────────┐
│  No worries, appreciate the update 👍 │
│                                       │
│  ↑ Send                    ✎ Edit   │
└─────────────────────────────────────┘
```

- `↑ Send` (bottom-left, amber) — inserts reply and dismisses. Same action as tapping the card.
- `✎ Edit` (bottom-right, amber) — existing behaviour, opens `.editReply` state
- Tapping anywhere on the card body still inserts (no behaviour change)
- The existing `arrow.up.circle.fill` `sendIcon` in `ReplyCardView` is replaced by the explicit `↑ Send` label

Dots (●○○) and Regenerate (↺) at end of tone row are already implemented — no changes needed.

---

## What Is Not Changing

- BackTap → AppIntent → App Group → keyboard poll architecture — unchanged
- Tone pills row layout and behaviour — unchanged
- Contact chip, EditContactView, DisambiguateView — unchanged
- ReplyCardsView scroll/paging — unchanged
- Companion app (Memory, Tones, Settings, Captures tabs) — unchanged
- Backend — unchanged

---

## Files Affected

| File | Change |
|------|--------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Add `ActionBarView` (idle/loading/error/capture states), new `KeyboardState` cases if needed |
| `ReplrKeyboard/KeyboardViewController.swift` | Remove height constants for `.loading` (50px) and error (220px) — both become 280px |
| `ReplrKeyboard/Views/LoadingView.swift` | Remove or repurpose — loading moves into action bar |
| `ReplrKeyboard/Views/ReplyCardView.swift` | Replace `sendIcon` with explicit `↑ Send` + `✎ Edit` footer |
| `Replr/Replr/App/ReplrApp.swift` | Handle `replr://setup` URL scheme → navigate to setup screen |
| `Replr/Replr/Features/Onboarding/OnboardingView.swift` | Reuse/extend for the setup screen opened from keyboard hint |

---

## Success Criteria

- A new user who has never configured BackTap sees a clear next step on first keyboard open
- Tapping the action bar button collapses the keyboard — no hunt for the ▾ chevron
- Keyboard never shrinks during loading or error
- Reply cards have a visible send button that first-time users can find without guessing
