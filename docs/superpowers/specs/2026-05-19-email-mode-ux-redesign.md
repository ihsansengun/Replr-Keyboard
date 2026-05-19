# Email Mode UX Redesign — Design Spec

## Goal

Redesign the keyboard strip and email mode UX. Key outcomes: icon-based mode row with an explicit Intent capture button, email mode that reads from the native app's text proxy, warm dark keyboard palette, and Paste + Regenerate in email replies.

---

## Color Palette

Replace the current `KBColors` block with warm dark tokens that complement mustard yellow.

| Token | Hex | Usage |
|---|---|---|
| `kbBg` | `#171209` | Keyboard shell background |
| `stripBg` | `#1E1912` | Mode row, tone row backgrounds |
| `stripBorder` | `#2E2518` | Row separators |
| `qwertyBg` | `#221D14` | QWERTY area background |
| `keyLetter` | `#EDE5D0` | Letter key face (warm cream) |
| `keyLetterFg` | `#1A1408` | Letter key text |
| `keyFn` | `#6B6050` | Function key face (warm taupe) |
| `keyFnFg` | `#EDE5D0` | Function key text |
| `keySpace` | `#D8D0BC` | Space bar |
| `keyShadow` | `#0A0803` | Key bottom shadow |
| `accent` | `#D4A017` | Mustard — active tab, intent captured, Send/Generate key |
| `accentFg` | `#120E00` | Text on mustard |
| `accentShadow` | `#7A5A00` | Send/Generate key shadow |

---

## Mode Row (28px) — Replaces current mode row + action bar

Three icon-only square tabs on the left, one text CTA that fills all remaining space on the right. No divider between them — all siblings on the same `#1E1912` surface with uniform `5px` padding and `3px` gaps.

```
[💬] [✉️] [🔖]  [  ↑ Generate from clipboard  ]   ← email
[💬] [✉️] [🔖]  [  ↑ Capture replies            ]   ← chat
```

### Icon tabs — SF Symbols

| Element | SF Symbol | Role |
|---|---|---|
| Chat mode | `bubble.left` | Mode selector |
| Email mode | `envelope` | Mode selector |
| Intent | `bookmark` | Intent capture button |

Tab shape: `border-radius: 6`, `width: 28pt`, `height: 20pt`, centered icon `14pt`, `stroke-width: 1.5`.

### Icon tab states

| Tab | State | Appearance |
|---|---|---|
| Active mode | Selected | Solid mustard fill, dark icon |
| Inactive mode | Unselected | Same icon, 35% opacity |
| Intent — empty | Nothing to capture | 18% opacity |
| Intent — ready | Text proxy has content | Mustard outline + 15% mustard fill |
| Intent — captured | Text saved | Solid mustard fill + small dark dot badge (top-right) |

### CTA text button

Fills remaining width (`flex: 1`). Same `border-radius: 6`, same `height: 20pt`. Text `11pt semibold`.

| Mode | Label | Style |
|---|---|---|
| Email | ↑ Generate from clipboard | Mustard tinted: `accent @ 12%` bg + `accent @ 38%` border + mustard text |
| Chat | ↑ Capture replies | Taupe tinted: `#6B6050 @ 18%` bg + taupe border + taupe text |
| Either, during replies | (label unchanged) | Transparent bg, no border, near-invisible text |

Tapping the email CTA triggers generation. Tapping the chat CTA is a hint only — Back Tap is the real capture trigger.

---

## Intent Button — Capture Flow

Intent is an **explicit capture action**, not automatic. The user types in the native app's text field using the Replr keyboard (exactly like a system keyboard), then taps the bookmark icon to lock that text as intent.

### Flow

1. **Empty** — text proxy empty → Intent icon is near-invisible (18% opacity). Nothing to capture.
2. **Ready** — user typed something in the host app's field → Intent icon lights up (mustard outline). Keyboard reads `textDocumentProxy.documentContextBeforeInput` on every `textDidChange`.
3. **Capture** — user taps Intent icon → reads text proxy → saves to `AppGroupService.shared.saveIntentHint(text)` → deletes the captured text from the text proxy (same as `onUseAsContext`) → icon becomes solid mustard with dot badge.
4. **Captured** — intent is locked. User can keep typing new text for other purposes. Tapping intent icon again clears it (`saveIntentHint(nil)`).
5. **After generation** — intent is cleared after a reply is inserted (existing `insert()` behaviour).

### KeyboardModel changes

| Property / callback | Change |
|---|---|
| `intentHint: String?` | Already exists — keep |
| `intentIncluded: Bool` | **Remove** — checkbox concept replaced by explicit capture |
| `captureIntent()` | Already exists — keep |
| `clearIntent()` | Already exists — keep |
| Intent icon state | Derived: `pendingContext.isEmpty && intentHint == nil` → empty · `!pendingContext.isEmpty && intentHint == nil` → ready · `intentHint != nil` → captured |

---

## Tone Row (32px)

Unchanged layout. One filter change: **Dating tone is hidden when `inputMode == .email`**.

Filtered list: `Tone.presets.filter { inputMode == .chat || $0.id != "dating" }`

---

## QWERTY Keyboard

Bottom-right key changes per mode:

| Mode | Key | Style |
|---|---|---|
| Chat | **Send** (48pt wide) | Solid mustard, `accentShadow` |
| Email | **return** (48pt wide) | Taupe fn key style — same as ⇧ and ⌫ |

Return key is preserved in email mode. Generation is triggered via the CTA button, not a keyboard key.

---

## Email Generation — Trigger

When user taps **↑ Generate from clipboard** CTA:

1. Read `UIPasteboard.general.string` → `emailText`. If nil/empty → `model.state = .error("No email in clipboard")`, return.
2. Read `model.intentHint` → optional intent string.
3. Clear text proxy draft and save `pendingContext = ""` to App Group (same as `onUseAsContext`).
4. `model.state = .loading`.
5. Background `Task` calls `ReplyService.shared.generateEmailReplies(emailText:intent:tone:...)` — a new method in `ReplyService` (Shared target) that POSTs to `/reply` with `emailText` + optional `summary`. The keyboard extension calls this directly via URLSession in a background Task.
6. On success → save replies to App Group → poll loop picks them up → `.replies` state.
7. On failure → `.error(message)`.

`onGenerateEmail: (() -> Void)?` callback on `KeyboardModel`, wired in `KeyboardViewController`.

---

## Replies State

### Email replies — card footer

Two equal buttons separated by a hairline:

```
┌──────────┬────────────┐
│  Paste   │ Regenerate │
└──────────┴────────────┘
```

- **Paste** → `model.onReplySelected(reply)` — inserts text into text proxy, same as Send in chat.
- **Regenerate** → `model.state = .idle`, `model.currentReplies = []`.

### Chat replies — card footer

Unchanged: single **Send** button.

`ReplyCard` receives `inputMode` and renders the appropriate footer.

---

## Height Changes

| State | Height |
|---|---|
| Idle (chat or email) | 308px — same as today |
| Loading | 308px |
| Error | 308px |
| Collapsed | 44px |
| Replies (chat) | Character-count heuristic, `chrome + cardHeight` |
| Replies (email) | Same heuristic, email scale: `min(340, max(200, longestReply × 0.8))` |

Strip is now 60px (mode row 28 + tone row 32) instead of 88px. The extra 28px is redistributed to card height, so total keyboard height stays the same.

---

## What Does NOT Change

- App Group communication, poll loop, `startCapturePoll()`
- Contact chip, contact disambiguation, undo chip
- Collapsed state
- `parseLlmOutput`, `generateRepliesFromEmail` on the backend
- Chat mode generation flow (Back Tap → AppIntent)

---

## Removed

- Standalone action bar row (28px) — merged into mode row
- `intentIncluded: Bool` property and checkbox UI
- `EditIntentView` (already dead code)
- `editIntent` keyboard state
