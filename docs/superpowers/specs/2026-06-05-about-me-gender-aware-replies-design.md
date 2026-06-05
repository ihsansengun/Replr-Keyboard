# "About Me" + gender-aware replies — design

**Status:** spec for review · **Date:** 2026-06-05 · **Approach chosen:** A (prompt upgrade) + an "About Me" profile field

## Problem

Reply quality suffers because the model has **no reliable signal for gender** — neither the user's own (the right-side person it writes *for*) nor the recipient's (left-side). Today it must guess from names/visuals. Consequences:

- In **grammatically-gendered languages** (Spanish, French, Arabic, Hebrew, Russian, Portuguese…), a wrong guess produces wrong adjective/verb endings — instantly "off" and AI-sounding.
- The **dating dynamic** reads differently man→woman vs woman→man vs same-sex — wrong assumptions flatten the flirt. (This matters even in non-gendered languages like Turkish.)
- The **user's own gender is essentially unknowable** from their side of the chat, so it can never be inferred — it must be provided.

## Decision

Two complementary changes:

1. **"About Me" profile field** (companion app) — one optional free-text box where the user describes themselves (age, gender, vibe, interests). Passed to the model so it knows *who it's writing for*. A free-text field (not a structured gender picker) is a better fit for Replr: one optional field, low friction, and it improves **every** reply (voice, interests) — not only gendered grammar.
2. **Prompt upgrade** — make the model explicitly reason about **the recipient's** likely gender (from the screenshot) and use correct gendered grammar, defaulting neutral when unsure. This is the "A" quick win and helps everyone immediately, even with About Me blank.

**Out of scope (deferred):** structured per-contact gender; the "infer → one-tap correct → remember on the `Contact`" loop (the richer "B" path). About Me covers the user's side; contact-level precision can layer on later if needed.

## The "About Me" field

- **Home:** a new **"About You"** section near the top of the **Settings** tab (companion app). (Not in onboarding for v1 — can surface there later.)
- **Form:** one optional, multi-line text box. ~**300-character cap** (keeps it focused and cheap per request).
- **Placeholder (concise):**
  > *A few words about you — age, gender, your vibe, what you're into. Helps Replr sound like you.*
  > *e.g. 27, guy, dry sense of humour, into climbing and techno.*
- **Privacy note under the field:** *"Stays on your device — sent only to draft your replies."*

## Data model + flow

- **`Constants.aboutUserKey = "about_user"`** (App Group key).
- **`AppGroupService.aboutUser: String`** accessor mirroring the `persistReplies` pattern:
  ```swift
  var aboutUser: String {
      get { defaults.string(forKey: Constants.aboutUserKey) ?? "" }
      set { defaults.set(newValue, forKey: Constants.aboutUserKey); defaults.synchronize() }
  }
  ```
- **`ReplyService`** — add an optional `aboutUser: String?` to all three request structs (`ReplyRequest`, `ReplyEmailRequest`, the inline `ScrollRequest`) and populate it from `AppGroupService.shared.aboutUser`, sending `nil` when blank (so the prompt block is omitted):
  ```swift
  aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
  ```
- **Backend `reply.ts`** — destructure optional `aboutUser` from the body on both `/reply` and `/reply/scroll`; thread into `generateReplies` / `generateRepliesFromEmail` / `generateRepliesFromMultiple`. (No new required-field validation — it's optional.)

## Prompt changes (`llm.ts`)

1. **Add `aboutUser?: string`** to `GenerateParams`, `GenerateEmailParams`, `GenerateMultipleParams`.
2. **Inject a user-profile block into the system prompt**, alongside `IDENTITY` + `ROLE` (stable per-user context). Only when present:
   ```
   ABOUT THE USER YOU'RE WRITING FOR (the right-side person — write in their voice):
   <aboutUser>
   ```
   Build the system as `[IDENTITY, ROLE: <tone>, <about block if any>].join('\n\n')`.
3. **Upgrade the gender reasoning** in `IDENTITY`/`DECISIONS` (static text), e.g. add to `DECISIONS`:
   - "Infer the **recipient's** (left-side) likely gender from their name, how the user addresses them, and content — and the user's own gender from the profile block above (if given)."
   - "In **grammatically-gendered languages**, get the gendered forms right for both people; when a person's gender is genuinely unclear, prefer **neutral** phrasing over guessing."
   - "Reflect the real dynamic between the two (e.g. the flirt reads differently depending on who is writing to whom)."

## Privacy

On-device storage (App Group); sent per request alongside the screenshot already being sent; **never persisted on the server** — consistent with the existing "nothing stored on our server" stance. The field is optional and user-controlled.

## Implementation touchpoints

| Area | File | Change |
|---|---|---|
| Key | `Shared/Constants.swift` | add `aboutUserKey` |
| Storage | `Shared/AppGroupService.swift` | add `aboutUser` accessor |
| Request | `Shared/ReplyService.swift` | add `aboutUser?` to 3 request structs + populate from App Group |
| UI | `Replr/Replr/Features/Settings/SettingsView.swift` | add "About You" section (multi-line field, placeholder, 300-cap, privacy note) bound to `AppGroupService.aboutUser` |
| Route | `backend/src/routes/reply.ts` | accept optional `aboutUser`, thread to services |
| Prompt | `backend/src/services/llm.ts` | add `aboutUser` to param types; system-prompt profile block; gender reasoning in `DECISIONS`/`IDENTITY` |
| Tests | `backend/tests/` | prompt includes the profile block when `aboutUser` is provided and omits it when absent; `aboutUser` is optional end-to-end |

## Testing

- **Backend (Vitest):** unit-test that the constructed prompt **includes** the "ABOUT THE USER…" block when `aboutUser` is set and **omits** it when undefined/empty; that `/reply` and `/reply/scroll` accept the optional field; `parseLlmOutput` is unchanged. (Mock the LLM clients as the existing tests do.)
- **iOS:** build green (app + keyboard share `Shared/`); manual check that the About You field saves, persists, and survives app relaunch; a live reply with About Me set reads in-voice.
- **Manual quality spot-check:** a gendered-language conversation produces correct gendered forms; a same-/opposite-sex dating chat reflects the right dynamic.

## Success criteria

- The user can enter/edit a self-description once; it's included in every subsequent reply request.
- Replies use the user's stated gender/voice, and handle the recipient's gender more correctly (right gendered grammar; neutral when unsure).
- Zero added friction in the screenshot→reply flow; the field is optional and everything still works when it's blank.

## Risks / notes

- **Token cost:** +up to ~300 chars/request in the system prompt — negligible.
- **Prompt-only inference for the recipient is still imperfect** — accepted for v1; the contact-level "correct & remember" loop is the deferred follow-up.
- **Sensitive content:** users may write anything in About Me; it's their own free text, used only to steer replies and not stored server-side. No validation beyond the length cap.
