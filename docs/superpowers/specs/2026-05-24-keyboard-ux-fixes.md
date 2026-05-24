# Keyboard UX Fixes — Round 3

**Date:** 2026-05-24  
**Scope:** 6 targeted fixes to the ReplrKeyboard extension UI

---

## Issue 1 — Stale contact name after new capture

**Problem:** The keyboard shows the previous capture's contact name (e.g. "Alex") even after a new generation for a different contact (e.g. "Erkan Eng") completes.

**Root cause:** The capture poll calls `consumeReplies()` when new replies arrive, then immediately reads `AppGroupService.shared.currentContactID`. The keyboard process reads from its in-memory UserDefaults cache, which has not yet received the intent process's write for the new contact ID. The contact ID update and the replies flag are written by the intent in sequence, but the keyboard sees them out of order.

**Fix:** In `AppGroupService.consumeReplies()`, call `defaults.synchronize()` before reading the replies key. This ensures the keyboard's cache is flushed before any subsequent App Group reads in the same poll tick. No other callers are affected.

---

## Issue 2 — Dead space in reply card

**Problem:** The `ReplyCarouselView` (`TabView`) expands to fill all remaining height in the `RepliesPanelView` VStack. Short replies leave a large empty gap below the text.

**Fix:**
- Reduce keyboard height for `.replies` state from `320pt` to `270pt` (chat) and `330pt` to `280pt` (email) in `KeyboardViewController.setHeight`.
- Constrain `ReplyCarouselView` to a fixed height of `88pt` using `.frame(height: 88)`. The `ScrollView` inside already handles longer replies with internal scroll.
- The contact header (28pt), page dots (17pt), action row (58pt), and tone row (38pt) remain unchanged. Total: 28 + 17 + 58 + 38 + 88 + header ≈ 270pt.

---

## Issue 3 — Reset button not visible

**Problem:** The `↺` (arrow.counterclockwise) reset button sits at the far right of the tone strip, hidden behind the fade-out gradient mask when tones overflow.

**Fix:** Remove the reset button from the tone strip in `RepliesPanelView` entirely. Add it to `RepliesPanelView`'s own inline header `HStack` (which does not use `KeyboardHeader`), between the `ModeSegmentedControl` and the trailing `Spacer`.

Layout of that header row after fix:  
`[Chat | Email]  [spacer]  [↺]  [REPLR mark]`

Since this header only renders inside `RepliesPanelView`, the button is naturally scoped to the replies state — no flag needed. The globe key remains in the tone strip as before.

---

## Issue 4 — Keyboard background appears as solid black block

**Problem:** The keyboard root view and collapsed strip both use `ReplrTheme.Color.bg` (`#0A0A0B` in dark mode), which renders as a solid black rectangle sitting on top of the chat — it does not blend with the native iOS keyboard chrome.

**Fix:** In `KeyboardViewController.viewDidLoad`, set `view.backgroundColor = .clear`. The `UIHostingController`'s view background is already `.clear`. With both clear, iOS renders its own standard keyboard background (translucent system chrome) behind the SwiftUI content. All panel views keep their internal surface colors for readability; only the outermost container becomes transparent.

No changes needed to `CollapsedStripView` background — once the root view is clear, the system chrome shows through underneath.

---

## Issue 5 — Collapsed bar: X button → chevron, tap whole bar

**Problem:** The `xmark` button in `CollapsedStripView` is small and only dismisses the coachmark. Users have no clear affordance to expand the keyboard, and the bar doesn't feel tappable.

**Fix:**

1. **Pill handle:** Add a 36×4pt rounded rectangle (`rgba(255,255,255,0.25)`) centred at the top of `CollapsedStripView`, above the card. Provides a bottom-sheet-like expand affordance.

2. **Replace xmark with chevron.up:** Swap `Image(systemName: "xmark")` for `Image(systemName: "chevron.up")` at the right edge of the card. Same size/frame (36×36pt), same secondary colour.

3. **Whole card is tappable:** Wrap the entire `HStack` card in a `Button` that calls `model.isCollapsed = false` (with animation). The chevron icon is no longer a separate `Button` — it becomes a visual indicator only, inside the parent button.

4. **Coachmark dismiss:** The coachmark still auto-dismisses on `onDisappear` and on the first tap of the card (call `dismissCoachmark()` at the start of the card's tap action).

5. **No change to coachmark text or logic** — only the visual X → chevron swap.

---

## Issue 6 — Idle state: replace "Capture this chat" button with instructional card

**Problem:** The full-width accent "Capture this chat" button dominates the idle state but teaches nothing. Users don't know why they should tap it or what happens next.

**Fix:** Replace `chatContent` in `IdlePanelView` with an instructional card layout (no full-width accent button):

```
┌─────────────────────────────────────────┐
│  HOW TO CAPTURE                         │
│  Open the chat, then collapse this      │
│  keyboard — Replr records what's on     │
│  screen when you double-tap.            │
│                                         │
│  ✦ Anything you've typed is sent as     │
│    context automatically                │
├─────────────────────────────────────────┤
│  Ready? Collapse to start    [Start ↓]  │
└─────────────────────────────────────────┘
```

- Top section: `"HOW TO CAPTURE"` label (uppercase, secondary), body copy, context hint line.
- Bottom section: prompt text (secondary) + small `"Start capture ↓"` button (accent fill, `font-size 12`, `height 32pt`) that calls `model.isCollapsed = true`.
- Card uses `ReplrTheme.Color.surface` background, `ReplrTheme.Radius.md` corner radius.

**Copy updates (double-tap throughout):** Replace every instance of `"triple-tap"` / `"Triple-tap"` with `"double-tap"` / `"Double-tap"` in:
- `CollapsedStripView` body text
- `CoachmarkBalloon` text
- `IdlePanelView` helper text (now inside the instructional card)

---

## Files affected

| File | Changes |
|---|---|
| `Shared/AppGroupService.swift` | Add `synchronize()` in `consumeReplies()` before reading replies key |
| `ReplrKeyboard/KeyboardViewController.swift` | `view.backgroundColor = .clear`; adjust `.replies` heights to 270pt (chat) / 280pt (email) |
| `ReplrKeyboard/Views/KeyboardView.swift` | `CollapsedStripView`: pill handle, xmark→chevron.up, whole-card tap gesture |
| `ReplrKeyboard/Views/RepliesPanelView.swift` | Inline header: add ↺ button + REPLR mark; `ReplyCarouselView` fixed to 88pt; remove reset button from tone strip |
| `ReplrKeyboard/Views/IdlePanelView.swift` | Replace `chatContent` with instructional card; double-tap copy |
