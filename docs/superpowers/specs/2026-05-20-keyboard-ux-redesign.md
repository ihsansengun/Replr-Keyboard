# Keyboard UX Redesign — Design Spec

## Goal

Rebuild every state of the Replr keyboard panel with a clear, consistent layout: labeled segmented mode control on top, scrollable tone pills, then a state-specific content area. Fix the screenshot capture flow so the keyboard actually disappears before the photo is taken.

## Architecture

Three structural layers stacked vertically in every state:

1. **Segmented control** (~50px) — Chat / Email toggle, always visible
2. **Tone row** (~30px) — scrollable pills + optional globe key, always visible
3. **Content area** (variable) — switches per state

`KeyboardRootView` drives layout via `KeyboardState`. `KeyboardViewController` manages the height constraint. `ReplrStrip` is replaced by the new `ModeSegmentedControl` + `ToneRow` components, which are composed into every state panel.

---

## Segmented Control

Full-width pill spanning the top of the panel, 7px top margin on each side.

```
┌─────────────────────────────┐
│  [message.fill]  Chat  │  [envelope.fill]  Email  │
└─────────────────────────────┘
```

- Background pill: `#2a2010`, corner radius 9
- Padding inside pill: 3px all sides, 2px gap between segments
- Each segment: icon (SF Symbol, 13pt) + label text (11pt semibold)
- **Active segment:** `#D4A017` fill, `#120E00` text
- **Inactive segment:** transparent fill, `#6B6050` text
- Switching mode: if state is `.replies`, call `regenerate()` first to reset to `.idle`
- Email mode: `Dating` tone hidden from tone row automatically
- Disabled (opacity 0.4, no interaction) during `.disambiguate` state only
- Height: 44px (including inner padding)

---

## Tone Row

Horizontally scrollable pill strip below the segmented control. Separator line above (0.5px `#2E2518`).

- Pills: `TonePill` component, unchanged visual design
- Active pill: `#D4A017` fill, `#120E00` text, semibold
- Inactive pill: `#241E13` fill, `#6B6050` text
- Globe key (if `needsGlobeKey`): right-anchored, separated by a 0.5px vertical divider
- Dimmed (opacity 0.35) during `.loading` state
- Normal (opacity 1.0) in all other states
- Height: 30px

---

## State: Idle — Chat Mode

Height: **270px**

Content area layout (below tone row):

```
┌────────────────────────────┐
│                            │  ← capture zone (rounded card, 8px radius)
│    [iphone.rear.camera]    │
│    ~~ripple animation~~    │
│   Back Tap to capture      │
│   screenshot → AI replies  │
│                            │
└────────────────────────────┘
 Reply to Sarah about…        ← draft preview row (dim, 1 line, truncated)
```

**Capture zone:**
- Background `#241E13`, 8px margin on all sides from panel edges
- Two concentric ripple circles (`Circle.stroke`, `#D4A017` at 0.75 opacity, 1.5px line) expanding from 6px → 44px diameter over 1.1s, staggered 0.55s, `easeOut`, `repeatForever(autoreverses: false)`
- `iphone.rear.camera` SF Symbol, 34pt light weight, `#D4A017`
- Label: "Back Tap to capture" 13pt semibold `#D4A017`
- Sublabel: "screenshot → AI replies" 11pt `#6B6050`

**Draft preview row:**
- 8px horizontal margin, 6px bottom margin
- Background `#1E1912`, 6px radius, 0.5px `#2E2518` border
- Shows `pendingContext` (text currently in the host app's text field), 9pt `#6B6050`, 1 line, truncated tail
- Hidden (zero height) when `pendingContext` is empty — no placeholder text

---

## State: Idle — Email Mode

Height: **270px**

Content area:

```
┌─────────────────────────────┐
│  📋  ↑ Generate from clipboard  │  ← yellow action button
└─────────────────────────────┘
  Copy the email text first, then tap above   ← hint
```

- Action button: `#D4A017` background, 9px radius, 8px all-side margin, 50px tall
- Icon: `doc.on.clipboard.fill` SF Symbol 16pt `#120E00`
- Label: "↑ Generate from clipboard" 12pt semibold `#120E00`
- Hint text: 10pt `#6B6050`, centred, below button
- Tapping button calls `generateEmailReply()`; if clipboard is empty, shows error state instead

---

## State: Capturing (screenshot in-flight)

Height: **0px**

When `switchKeyboardRequested` is detected in the poll loop:
1. Clear the flag in App Group
2. Animate `heightConstraint.constant` to 0 over 0.15s (`easeInOut`)
3. iOS reflows the host app — conversation fills the screen
4. `PrepareForCaptureIntent` completes its 2s wait, `Take Screenshot` fires
5. `GenerateReplyIntent` runs; writes `isGenerating = true` then replies to App Group
6. Poll loop detects replies → animate height back to replies height
7. State transitions to `.replies([String])`

The keyboard stays at 0px height and shows no UI during capture + generation. No loading state is shown while at 0px.

---

## State: Loading

Height: **200px**

Content area:

```
  ⟳  Generating replies…       ← spinner + label row
  ████████████████░░░░░░        ← skeleton line 1 (80% width)
  █████████████████████░░░      ← skeleton line 2 (95% width)
  ████████████████░░░           ← skeleton line 3 (65% width)
```

- Spinner: `ProgressView` circular, scale 0.55, tinted `#D4A017`
- Label: "Generating replies…" 11pt `#D4A017` at 60% opacity
- Skeleton lines: `#2a2010` → `#3a3018` shimmer gradient, 10px tall, 4px radius, animated
- Tone row dimmed (0.35 opacity) in this state

---

## State: Replies

Height: **dynamic** = `max(200, 100 + (count × 52))`, capped at **340px**

where 100 = segmented(44) + tone(30) + contact chip(26), 52 = card height + gap

Layout:

```
[Contact chip row]
─────────────────────────────── 0.5px separator
[Reply card 1]
[Reply card 2]
[Reply card 3 … up to 5]
```

**Contact chip row** (26px):
- `person.fill` SF Symbol 9pt + contact name 12pt, `#D4A017`, left-aligned, 14px leading padding
- "↺ New replies" link right-aligned, 10pt `#6B6050`; tapping calls `regenerate()`

**Reply card** (compact row, Style A):
- Background `#241E13`, 8px radius, 0.5px `#2E2518` border
- 10px vertical padding, 10px horizontal padding
- Text: 13pt `#EDE5D0`, up to 3 lines, `.leading` aligned, `lineLimit(3)`
- `Edit` button: 11pt `#6B6050`, `#241E13` background, 5px radius, 8px horizontal / 5px vertical padding. Tapping calls `editReply(_:)` → clears draft in proxy, inserts reply text, switches keyboard
- Send button: 28×28px, 5px radius, `#D4A017` background, `arrow.up` SF Symbol 11pt semibold `#120E00`. Tapping calls `selectReply(_:)`

---

## After-Send: Undo State

Duration: **1.5 seconds**, then keyboard auto-switches via `advanceToNextInputMode()`

The **Send button on the tapped card** morphs in-place:
- Sent card: background changes to `#1a1a10`, border `#D4A017` at 18% opacity
- Send button (`arrow.up`, yellow): crossfades to `↩` symbol, background becomes `#3a2a00`, border `1px #D4A017`, text `#D4A017`
- Sent card text: `#6B6050` (dimmed)
- `Edit` button: hidden (opacity 0) on sent card
- All other cards: opacity 0.35
- Tapping the ↩ button: calls `undoLastInsert()`, restores cards to normal
- After 1.5s with no undo: `lastInsertedReply = nil`, `advanceToNextInputMode()` fires

Implementation: `model.lastInsertedReply` identifies which card is the sent card. The `ReplyRowView` receives a `isSent: Bool` parameter to render the morphed state.

---

## State: Error

Height: **200px**

Content area centred vertically:

```
      ⚠️
  [error message — up to 3 lines, centred]
      [↺ Retry]
```

- Icon: `exclamationmark.triangle.fill` SF Symbol 18pt `#D4A017` at 80% opacity
- Message: 12pt `#6B6050`, multiline centred, 24px horizontal padding
- Retry button: "↺ Retry" 12pt medium `#EDE5D0`, `#241E13` background, 6px radius, 0.5px `#2E2518` border, 16px horizontal / 6px vertical padding
- Tapping Retry calls `retryGeneration()`

---

## State: Disambiguate

Height: **300px**

```
[Segmented control — dimmed 0.4 opacity, non-interactive]
[Tone row — hidden]
┌─────────────────────────────┐
│ Which [name]?               │  ← header row
├─────────────────────────────┤
│ [avatar]  Name              │  ← contact row (tappable)
│           Last: "summary"   │
├─────────────────────────────┤
│ [avatar]  Name              │
│           Last: "summary"   │
├─────────────────────────────┤
│ ＋ New contact named [name] │  ← create-new row
└─────────────────────────────┘
```

- Header: 10pt semibold `#EDE5D0`, `#1E1912` background, 9px padding, bottom separator
- Avatar: 32×32px circle, `#241E13` fill, `person` SF Symbol 12pt if no thumbnail
- Contact name: 13pt `#EDE5D0`; last summary: 11pt `#6B6050`, 1 line truncated
- Row height: 52px min
- Create-new: `plus.circle` + "New contact named [name]" 13pt `#D4A017`
- Tone row is hidden (height 0) in this state to give more vertical space

---

## Heights Summary

| State         | Height |
|---------------|--------|
| Idle          | 270px  |
| Loading       | 200px  |
| Replies (N)   | min(340, 100 + N × 52)px |
| Error         | 200px  |
| Disambiguate  | 300px  |
| Capturing     | 0px    |

Height transitions: `UIView.animate(withDuration: 0.25)` on the height constraint, except capture collapse which uses 0.15s.

---

## Colors (unchanged)

```swift
accent        #D4A017  // mustard yellow
accentFg      #120E00  // dark for text on yellow
background    #171209  // keyboard shell
deep          #1E1912  // strip rows
surface       #241E13  // card surfaces
borderHair    #2E2518  // hairline separators
borderDim     #3A3020  // dimmer borders
textPrimary   #EDE5D0  // reply text
textDim       #6B6050  // secondary text / inactive
```

---

## Files to Create / Modify

| File | Change |
|------|--------|
| `ReplrKeyboard/Views/KeyboardView.swift` | Replace `ReplrStrip` with `ModeSegmentedControl`; update `KeyboardRootView` state switch; update `KeyboardModel` |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Add segmented control + tone row; update capture zone layout; add draft row |
| `ReplrKeyboard/Views/ReplyListView.swift` | Add `isSent` param to `ReplyRowView`; morph send→undo button |
| `ReplrKeyboard/Views/LoadingPanelView.swift` | New file: spinner label + skeleton lines |
| `ReplrKeyboard/Views/ErrorPanelView.swift` | New file: icon + message + retry |
| `ReplrKeyboard/KeyboardViewController.swift` | Collapse-to-0 logic for `switchKeyboardRequested`; update height map |
| `Replr/Replr/Intents/PrepareForCaptureIntent.swift` | No change needed (flag + 2s wait already correct) |
