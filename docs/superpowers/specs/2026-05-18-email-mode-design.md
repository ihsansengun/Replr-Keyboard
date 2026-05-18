# Email Mode — Design Spec

**Date:** 2026-05-18  
**Status:** Approved

---

## Problem

Email replies are already supported in the backend (`generateRepliesFromEmail`) and `ReplyService`, but there is no keyboard UX for it. Currently "email" exists as a tone pill alongside "casual" and "bold", which is misleading — email changes the *input method* (clipboard text instead of screenshot), not just the LLM style. This spec defines the full keyboard UX for email mode.

---

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where does email mode live? | Keyboard extension only | Zero app-switching; user is already composing a reply |
| How is it triggered? | Mode tab (Chat / Email) above tone pills | Visually unambiguous — a tab clearly signals mode, not style |
| How is email text sourced? | Single "Paste & Generate" button reads clipboard | Fastest possible flow; one tap after selecting the mode |
| Where does the API call happen? | Directly in the keyboard process | Can't trigger AppIntents from keyboard extensions; ReplyService is already available in Shared/ |
| Replies / loading UI? | Reuse existing states unchanged | No new UI needed post-generate |
| Contact / memory? | Auto-detected from email by LLM (same as screenshot flow) | Email headers give LLM sender name; memory summaries passed as `previousContext` |
| "email" tone in tone list? | Removed | The mode tab owns that distinction; keeping it would create duplicate signals |

---

## UI Structure

### New: Mode Row

A permanent row sits above the tone pills in all keyboard states:

```
[ 💬 Chat ]  [ ✉ Email ]                              ⌄
```

- Height: 28px
- Background: `KBColors.deep` (#0D0D0D), separator below
- Active tab: amber text + `KBColors.amberBg` background, rounded 4px
- Inactive tab: `KBColors.textDim` text, no background
- Tapping a tab switches mode instantly with `.easeInOut(0.2)` animation
- The chevron (collapse) stays right-aligned in this row

### Keyboard Heights (updated)

| State | Height (was) | Height (new) |
|---|---|---|
| idle | 280px | 308px |
| loading | 280px | 308px |
| error | 280px | 308px |
| replies | 320px | 348px |
| disambiguate | 320px | 348px |
| editReply | 280px | 308px |
| editContact | 280px | 308px |
| collapsed | 44px | 44px (unchanged) |

The 28px delta is the mode row height, added to every state except collapsed.

### Chat Mode (unchanged except height)

The QWERTY keyboard and all existing state views render exactly as before under the mode row. No functional changes to chat mode.

### Email Mode — Idle State

When the Email tab is active and no generation is in flight:

```
[ 💬 Chat ]  [ ✉ Email ✓ ]                            ⌄
[ casual ]  [ professional ]  [ formal ]  [ friendly ] …
─────────────────────────────────────────────────────────
              [ ✉  Paste & Generate ]
              "Reads email from clipboard"
```

- The QWERTY keyboard is replaced by a centred `Paste & Generate` button
- Subtitle hint: "Reads email from clipboard" in `KBColors.textDim`
- Tone pills remain; the selected tone is passed to the API as the reply style
- Tones reordered for email context: professional, formal, casual, friendly, bold, witty (dating hidden in email mode)

### Email Mode — Generate Flow

1. User taps **Paste & Generate**
2. Read `UIPasteboard.general.string` — if nil or empty, set `model.state = .error("No text on clipboard. Copy the email first.")` and return
3. Set `model.state = .loading` (reuses existing loading UI in ReplrStrip)
4. Dispatch a `Task { @MainActor in … }` to call `ReplyService.shared.generateRepliesFromEmail(emailText:tone:summary:previousContext:model:transactionId:)` — `summary: nil`, `previousContext` from current contact summaries if available, `transactionId` from App Group
5. **On success:** save `CaptureSession` to App Group (same as screenshot flow), call `AppGroupService.shared.saveReplies(replies)`, update `model.currentReplies`, set `model.state = .replies(replies)`
6. **On failure:** set `model.state = .error(error.localizedDescription)`

Contact resolution (find/create from LLM-detected name) runs identically to `GenerateReplyIntent`. The logic is currently inlined in both `GenerateReplyIntent` and `QuickReplyIntent` — extract it into a free function in `Shared/` (e.g., `resolveContact(from result: ReplyResult) -> (id: UUID?, name: String?)`) so the keyboard can call the same code without duplication.

`previousContext`: read recent summaries for `AppGroupService.shared.currentContactID` if set (identical to chat mode). On first email from an unknown sender this will be nil, which is fine — the LLM will detect the contact name and it will be set for future requests.

`summary`: pass `nil` — email mode has no pending context input field.

### Email Mode — Replies + Error

Identical to chat mode. The mode tab remains visible so the user can see they're in email mode and switch back. Regenerate (↺ button) re-shows the `Paste & Generate` button, not the QWERTY.

---

## KeyboardModel Changes

```swift
// New mode enum
enum KeyboardInputMode { case chat, email }

// New published property
@Published var inputMode: KeyboardInputMode = .chat
```

`KeyboardState` does not need a new email case — the `inputMode` property controls what the idle body renders. Loading/replies/error are shared between both modes.

---

## KeyboardViewController Changes

- Height constraint values increase by 28px across all states (see table above)
- The `stateCancellable` switch maps heights to the updated values
- `startCapturePoll()` is unchanged — it still polls App Group for replies written by any source

---

## Tone List Changes

- Remove "email" from `Tone.presets` (it's now a mode, not a tone)
- Add tone ordering preference: in email mode, the tone scroll view starts at "professional" rather than "casual"
- "dating" tone is hidden when `inputMode == .email`

---

## Backend

No changes required. `POST /reply` already handles `emailText` in place of `screenshotBase64`. The `model` field stays `"claude"`.

---

## Out of Scope

- Sharing/exporting the generated email reply (user copies from the insert flow as normal)
- Email-specific memory tracking (uses the same `CaptureSession` + contact system)
- Detecting clipboard content type automatically (user explicitly taps the button, so intent is clear)
