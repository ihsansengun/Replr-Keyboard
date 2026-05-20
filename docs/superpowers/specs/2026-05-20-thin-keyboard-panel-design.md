# Replr Thin Keyboard Panel — Design Spec

**Date:** 2026-05-20
**Status:** Approved for implementation

## Problem

The current Replr keyboard extension ships a full custom QWERTY layout. This makes it incompatible as a daily-driver keyboard for users who type in any language other than English — they cannot type naturally in Turkish, Arabic, French, etc. The keyboard must be a daily driver to deliver on Replr's core value: AI reply suggestions available without leaving the keyboard.

## Solution

Replace the full custom keyboard with a thin AI panel (no QWERTY). The system keyboard handles all typing in the user's native language. Replr is a momentary tool — the user switches to it via the globe key, picks a reply, and is sent back automatically.

---

## Design Decisions

| Question | Decision |
|---|---|
| Interaction model | Model B: thin keyboard extension, no QWERTY |
| Idle state size | ~240px full panel |
| Reply display | Vertical list, each row has Send + Edit |
| Capture trigger | Back Tap only (GenerateReplyIntent, works from any keyboard) |
| Edit reply | Pre-fill text field + immediate switch to system keyboard |
| Contact naming | Read-only chip in panel; renaming moves to companion app |
| Undo window | 1.5s after Send before auto-switch |

---

## State Machine

### States

| State | Height | Description |
|---|---|---|
| `.idle` | 240px | Capture zone + last contact/context preview |
| `.loading` | 160px | Strip + skeleton lines |
| `.replies([String])` | ~220px (dynamic) | Strip + vertical reply list |
| `.error(String)` | 160px | Strip + error message + Retry |
| `.disambiguate(name:candidates:)` | 280px | Strip + contact picker list |

### Removed States

- `.collapsed` — no longer needed; Back Tap fires from any active keyboard
- `.editReply` — replaced by pre-fill + auto-switch (see Interactions)
- `.editContact` — contact renaming moves to companion app

### Removed Model Properties

`KeyboardModel` loses: `inputText`, `isShifted`, `kbMode`, `onTypeChar`, `onDeleteChar`, `onSpaceChar`, `onReturnChar`, and all input/edit methods (`type(_:)`, `backspace()`, `space()`, `toggleShift()`, `toggleMode()`, `confirmInput()`, `cancelInput()`, `enterEditReply(_:)`, `enterEditContact(_:)`).

---

## Panel Layouts

### Idle (~240px)

```
┌─────────────────────────────────────┐
│ [Chat▼] [Email] [◎]          🌐    │  ← Mode row (36px)
├─────────────────────────────────────┤
│ ●Casual  Formal  Funny  Sharp       │  ← Tone row (32px)
├─────────────────────────────────────┤
│                                     │
│       ✦                             │
│   Back Tap to capture               │  ← Capture zone (dashed border)
│   screenshot → AI replies           │
│                                     │
├─────────────────────────────────────┤
│  (S)  Sara · 4 min ago              │  ← Last capture preview card
│       "Yeah sounds great…"          │    (hidden if no sessions yet)
└─────────────────────────────────────┘
```

### Loading (~160px)

```
┌─────────────────────────────────────┐
│ [Chat▼] [Email] [◎] ● Generating…  │
├─────────────────────────────────────┤
│ ●Casual  Formal  Funny              │
├─────────────────────────────────────┤
│  ████████████  ████████             │
│  ████████████████  ██████           │  ← Skeleton lines
│  ████████  ████████████             │
└─────────────────────────────────────┘
```

### Replies (dynamic; 68 strip + 8 padding + count × 52, capped at 320px with ScrollView)

```
┌─────────────────────────────────────┐
│ [Chat▼] [Email] [◎] ●Sara  ↻  🌐   │
├─────────────────────────────────────┤
│ ●Casual  Formal  Funny              │
├─────────────────────────────────────┤
│  "Yeah I'll be there around 8! 🎉"  [Edit][↑] │
├─────────────────────────────────────┤
│  "Sounds good, see you tonight!"    [Edit][↑] │
├─────────────────────────────────────┤
│  "Of course! What time?"            [Edit][↑] │
└─────────────────────────────────────┘
```

### Error (~160px)

```
┌─────────────────────────────────────┐
│ [Chat▼] [Email] [◎] ⚠ Failed  [Retry] 🌐 │
├─────────────────────────────────────┤
│ ●Casual  Formal  Funny              │
├─────────────────────────────────────┤
│                                     │
│   Rate limit reached. Try again     │
│   tomorrow or upgrade to Premium.   │
│              [↻ Retry]              │
└─────────────────────────────────────┘
```

---

## Key Interactions

### Send flow
1. User taps `↑` on a reply row
2. `textDocumentProxy.deleteBackward()` clears any draft
3. `textDocumentProxy.insertText(reply)` inserts the reply
4. `model.lastInsertedReply = reply` is set; panel stays in `.replies` state — `ReplrStrip` already shows the Undo chip when `lastInsertedReply != nil`
5. After 1.5s `lastInsertedReply` is cleared and `advanceToNextInputMode()` switches back to system keyboard (or immediately if Undo is tapped, which deletes the inserted text instead)

### Edit flow
1. User taps `Edit` on a reply row
2. `textDocumentProxy.insertText(reply)` pre-fills the reply into the text field
3. `advanceToNextInputMode()` switches immediately to system keyboard
4. User edits the pre-filled text in their own language

### Back Tap capture flow
1. User is typing in system keyboard (any language)
2. Back Tap fires `GenerateReplyIntent` in companion app process
3. Intent captures screenshot via broadcast extension, calls backend, stores replies in App Group
4. User taps globe → switches to Replr keyboard
5. `viewWillAppear` polls App Group: if replies ready → `.replies([String])`; if generating → `.loading`

### Disambiguate flow
- Unchanged from current implementation; no text input needed, just a list picker

---

## Code Changes

### Files deleted
- `ReplrKeyboard/Views/IdleView.swift` — replaced by new `IdlePanelView`
- All QWERTY key components inside `KeyboardView.swift` (`ReplrKeyboard`, `CharKey`, `ShiftKey`, `DeleteKey`, `SpaceKey`, `ModeKey`, `DoneKey`, `KBInputArea`, `EditContactView`)
- `KBMode` enum (alpha/numeric keyboard toggle) — no longer needed without a QWERTY
- `IdleView.swift` — legacy UIKit file, already dead code

### Files modified
- `ReplrKeyboard/Views/KeyboardView.swift` — remove QWERTY, remove `.collapsed`/`.editReply`/`.editContact` branches, update height map
- `ReplrKeyboard/KeyboardViewController.swift` — remove `onTypeChar`, `onDeleteChar`, `onSpaceChar`, `onReturnChar`, `onConfirmContact`, `onDifferentPerson`, `onSelectContact`, `onCreateNewContact` callbacks; simplify height constraint logic

### New views
- `IdlePanelView` — capture zone + last capture preview card
- `ReplyListView` — vertical list of `ReplyRowView` items
- `ReplyRowView` — reply text + Edit + Send buttons

### Height constants (replacing current map)
```swift
switch state {
case .idle:          240
case .loading:       160
case .replies:       dynamic (68 strip + 8 padding + count × 52, max 320 with ScrollView)
case .error:         160
case .disambiguate:  280
}
```

---

## What Does Not Change

- `AppGroupService`, `Constants`, all shared models — untouched
- `GenerateReplyIntent`, `ReplyService`, `CaptureService` — untouched
- `ReplrStrip` — kept as-is (mode tabs, tone pills, CTA area, globe key)
- Broadcast extension, companion app, backend — untouched
- The email mode (generate from clipboard) — kept, triggered from strip CTA
- Intent capture (context hint) — kept in strip
