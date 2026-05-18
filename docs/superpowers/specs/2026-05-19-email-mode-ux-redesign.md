# Email Mode UX Redesign — Design Spec

## Goal

Redesign the email mode keyboard UX so it is nearly identical to chat mode — same QWERTY layout, same strip — with the only differences being a live intent row (checkbox), a Generate key, and Paste + Regenerate in the replies state. Remove all previously-built email-specific UI (paste button, EditIntentView wiring, explicit intent capture).

---

## Core Mental Model

- The user types their reply intent directly into the host text field, exactly like they would type in chat.
- Whatever is in the text proxy at generate-time IS the intent. No explicit capture step.
- "Generate" reads the email from the clipboard and optionally the typed intent.
- The intent row is a live reflection of `pendingContext` — it appears and disappears automatically as the user types.

---

## Color Palette

The keyboard adopts a warm dark theme that complements mustard yellow. Applied to all modes (chat and email share the same keyboard appearance).

| Token | Hex | Usage |
|---|---|---|
| `kbBg` | `#171209` | Keyboard shell background |
| `stripBg` | `#1E1912` | Mode row, action bar, tone row backgrounds |
| `stripBorder` | `#2E2518` | Row separators |
| `qwertyBg` | `#221D14` | QWERTY area background |
| `keyLetter` | `#EDE5D0` | Letter key face (warm cream) |
| `keyLetterFg` | `#1A1408` | Letter key text |
| `keyFn` | `#6B6050` | Function key face (⇧ ⌫ 123, warm taupe) |
| `keyFnFg` | `#EDE5D0` | Function key text |
| `keySpace` | `#D8D0BC` | Space bar face |
| `keyShadow` | `#0A0803` | Key bottom shadow |
| `accent` | `#D4A017` | Mustard — Generate/Send key, active tab, active tone, intent checkbox |
| `accentFg` | `#120E00` | Text on mustard |
| `accentShadow` | `#7A5A00` | Generate/Send key bottom shadow |

Replace the current `KBColors` static block in `KeyboardView.swift` with these values.

---

## Strip (top 88px — identical in both modes)

```
┌─────────────────────────────────────┐  28px  mode row
│  💬 Chat   [✉️ Email]               │
├─────────────────────────────────────┤  28px  action bar
│  [↑ Generate from clipboard]        │  ← email
│  [↑ Capture replies]                │  ← chat
├─────────────────────────────────────┤  32px  tone row
│  [Casual] Friendly  Professional…   │
└─────────────────────────────────────┘
```

- **Email action bar**: full-width centered label "↑ Generate from clipboard" in mustard, no button (tapping it is not needed — Generate key handles it).
- **Dating tone** is hidden when `inputMode == .email`. The filtered list is `Tone.presets.filter { $0.id != "dating" }`.

---

## Intent Row (email mode only, 28px, conditional)

Sits between the tone row and the QWERTY area. Visible only when `pendingContext.trimmingCharacters(in: .whitespacesAndNewlines)` is non-empty AND `inputMode == .email`.

```
┌──────────────────────────────────────┐
│  [✓]  Ask Bob to review the timeline  ·  tap to exclude  │
└──────────────────────────────────────┘
```

- **Checkbox checked (default)**: mustard fill, `✓` glyph, intent text in `#C8BFA8`, hint "tap to exclude" in taupe.
- **Checkbox unchecked**: taupe border, intent text struck-through in `#3A3020`, hint "tap to include".
- Tapping the row toggles `model.intentIncluded: Bool` (new property, default `true`).
- The row's height is 28px. Adding it shifts QWERTY down — total keyboard height becomes 308 + 28 = 336px when visible.
- `KeyboardViewController` must update `setHeight` when the intent row appears/disappears. Subscribe to `model.$pendingContext` and `model.$inputMode` to detect transitions.

---

## QWERTY Keyboard

Identical layout for both modes. Only the bottom-right key changes:

| Mode | Bottom-right key |
|---|---|
| Chat | **Send** (mustard, 48px wide) — inserts `\n` or submits |
| Email | **Generate** (mustard, 64px wide) — triggers email generation |

The `KBInputArea` bottom row switches key based on `model.inputMode`.

---

## Generate Action (email mode)

When the user taps Generate, `KeyboardViewController` executes:

1. Read `textDocumentProxy.documentContextBeforeInput` → `intentText`.
2. Read `UIPasteboard.general.string` → `emailText`. If nil/empty, transition to `.error("No email in clipboard")` and return.
3. Clear the text proxy draft (delete chars, same as `onUseAsContext` today). Save `pendingContext = ""` to App Group.
4. Transition to `.loading`.
5. Fire a background `Task` that calls `ReplyService.shared.generateEmailReplies(emailText:intent:tone:...)` — a new method in `ReplyService` (companion app target, Shared/) that POSTs to `/reply` with `emailText` + optional `summary`. The keyboard extension calls this directly via `URLSession` in a background task; this is intentional — the keyboard owns the email generation flow since it holds the clipboard and intent context.
6. On success: write replies to App Group (`AppGroupService.shared.saveReplies`). The existing poll loop in `startCapturePoll()` picks them up and transitions to `.replies`.
7. On failure: write error to App Group or call the error path directly on `MainActor`.

`onGenerateEmail: (() -> Void)?` callback added to `KeyboardModel`, wired in `KeyboardViewController`.

---

## Replies State (email mode)

Card footer shows two buttons instead of one:

```
┌──────────────────────────────────────┐
│  Hi Bob,                             │
│                                      │
│  I've reviewed the timeline…         │
├──────────┬───────────────────────────┤
│  Paste   │  Regenerate               │
└──────────┴───────────────────────────┘
```

- **Paste**: calls `model.onReplySelected(reply)` — inserts the reply text into the text proxy (same as Send in chat). Label: "Paste".
- **Regenerate**: resets `model.state = .idle`, clears `model.currentReplies`. User is back at the QWERTY keyboard to adjust intent and tap Generate again. Label: "Regenerate".
- In chat mode, the card footer remains a single "Send" button (unchanged).

`ReplyCard` receives `inputMode` and renders the appropriate footer.

---

## KeyboardModel Changes

| Property / method | Change |
|---|---|
| `intentIncluded: Bool` | New `@Published` property, default `true`. Reset to `true` when `inputMode` switches. |
| `onGenerateEmail: (() -> Void)?` | New callback, called when Generate key tapped in email mode. |
| `regenerate()` | Existing — sets state to `.idle`, clears replies. Reused by Regenerate button. |

---

## KeyboardViewController Changes

- Wire `model.onGenerateEmail` — reads clipboard, calls `AppGroupService` to queue an email generation request, same mechanism as `GenerateReplyIntent` but triggered from keyboard.
- Subscribe to `model.$pendingContext.combineLatest(model.$inputMode)` to detect when intent row appears/disappears (email mode + non-empty context) and call `setHeight(336)` vs `setHeight(308)`.

---

## What Does NOT Change

- Chat mode keyboard: no changes to behavior, layout, or Generate/Send semantics.
- The `AppGroupService` poll loop and reply delivery mechanism.
- `parseLlmOutput`, `generateRepliesFromEmail` on the backend.
- Contact chip, tone persistence, undo chip, collapsed state.
- The `.loading` and `.error` strip states.

---

## States Not Affected

`editReply`, `editContact`, `disambiguate`, `collapsed` — all unchanged.

---

## Out of Scope

- Persisting intent across keyboard sessions (the intent lives only in the text proxy during the session).
- Multiple email generations with different intents in one session (user edits text proxy and taps Generate again).
