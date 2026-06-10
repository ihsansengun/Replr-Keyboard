# Dating Mode v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship dating mode per `docs/superpowers/specs/2026-06-10-dating-mode-design.md` — a third keyboard mode with a fully separate backend prompt family (profile → openers, empty chat → pick-up lines, ongoing → escalating replies), 11 dating-specific tones + 4 shared, mode persistence for intent paths, always-on match memory, and a separated Dating section in Settings.

**Architecture:** Backend: `mode: 'dating'` on `POST /reply` selects `DATING_IDENTITY`/`DATING_DECISIONS` instead of the chat prompts; the output format gains a leading `CONTEXT: profile|empty|chat` line parsed into an optional `contextType` (returned in JSON; no client UI consumes it in v1). iOS: `KeyboardInputMode.dating` persisted to the App Group so Back Tap/QuickReply intents use the right family; tone availability follows the existing static-name-set pattern (`datingToneNames`); dating generations always send memory.

**Tech Stack:** Existing Hono/Vitest backend, SwiftUI keyboard + app, no new dependencies.

**Verification gates:** backend `cd backend && npm run typecheck && npm test`; iOS `cd Replr && xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build`. Commit per task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer. NEVER deploy/push unprompted.

---

## Task 1: Backend — 11 dating TONE_LIBRARY entries

**Files:** Modify `backend/src/services/tones.ts` (append before the `Dating` backward-compat alias), `backend/tests/tones.test.ts`

- [ ] **Step 1.1 — failing test** (append to tones.test.ts):

```ts
describe('dating tones', () => {
  const DATING = ['Tease','Smooth','Bold','Banter','Intrigue','Challenge','Closer','Revive','Recovery','Slow Burn','Spice']
  it('resolves every dating tone with examples and a temperature', () => {
    for (const name of DATING) {
      const spec = toneSpecFor(name, 'sent instruction')
      expect(spec.examples.length, name).toBeGreaterThanOrEqual(3)
      expect(spec.temperature, name).toBeGreaterThan(0)
      expect(spec.baseOnly, name).toBe(false)
      expect(spec.voice, name).toBe('sent instruction')   // voice comes from the iOS instruction, like chat tones
    }
  })
})
```

Run `npm test -- tests/tones.test.ts` → FAIL (unknown keys fall back to default temp 0.85 but… the failing assertion is examples.length ≥ 3).

- [ ] **Step 1.2 — implement.** Append to `TONE_LIBRARY` under a `── Dating mode ──` banner comment (temperatures + examples exactly as below; examples are flavor-only):

```ts
  // ── Dating mode (separate family — never shown in chat/email) ─────────────
  'Tease':     { temperature: 0.90, examples: [
    "a golden retriever AND an oat milk order in the same profile… dangerously close to a walking cliché. lucky for you it's working",
    "we'd argue about the aux cord within a week and you know it",
    "i was going to open with something nice but your taste in pizza toppings needs addressing first",
  ] },
  'Smooth':    { temperature: 0.85, examples: [
    "okay the hiking photo sold me — anyone who climbs that far for a view has taste. dinner views are easier though",
    "you have the kind of smile that makes someone forget their opener. i had one. it's gone",
    "see, now you're just showing off. keep going",
  ] },
  'Bold':      { temperature: 0.80, examples: [
    "you seem like trouble in the best way. drinks thursday — i know a place that matches your tattoo energy",
    "i don't do small-talk marathons. you're interesting, i'm interested. that taco place in your third photo, this week?",
    "matching with you was the easy part. now i'm pretending i haven't already planned where we're going",
  ] },
  'Banter':    { temperature: 0.95, examples: [
    "ranking your photos: 1) the dog 2) the pasta 3) you. it's a competitive lineup, don't take it personally",
    "your bio says 'fluent in sarcasm' — finally someone i can marry for tax purposes AND emotional damage",
    "petition to hear the full karaoke-photo story. i've already taken a side and need to know if i'm right",
  ] },
  'Intrigue':  { temperature: 0.90, examples: [
    "i have a theory about you based entirely on your second photo. it's flattering. mostly",
    "there's something in your bio most people scroll right past. i didn't",
    "you remind me of someone i almost didn't recover from. anyway — coffee?",
  ] },
  'Challenge': { temperature: 0.85, examples: [
    "cute profile. but everyone's adventurous on here — what's the last thing you did that actually scared you?",
    "i'm 70% convinced. the other 30% depends on your taco order",
    "you say you're competitive — name the game. loser plans the first date",
  ] },
  'Closer':    { temperature: 0.80, examples: [
    "we've established you have good taste and i'm a great time. thursday, that wine bar — i'll book it",
    "this is officially too fun for an app. number, before hinge starts charging us rent",
    "you free saturday or do i have to keep being charming until you are?",
  ] },
  'Revive':    { temperature: 0.90, examples: [
    "so anyway, back to what's important: did the pasta place live up to the hype or not",
    "i'm choosing to believe you got lost in ikea and only just found wifi. welcome back",
    "resurfacing like that voice memo you never sent. how was the trip?",
  ] },
  'Recovery':  { temperature: 0.90, examples: [
    "i see my last message is doing community service in your read pile. it deserves a second chance",
    "in my defense, that joke was funnier in my head. let's pretend i said something charming about your dog instead",
    "new topic: what's a hill you'd actually die on? mine is that read receipts build character",
  ] },
  'Slow Burn': { temperature: 0.80, examples: [
    "i was going to ask something flirty but honestly i'm more curious what made you move cities",
    "you said that like someone with a story. i've got time",
    "okay we'll get back to the banter — first, the bookshop photo. explain",
  ] },
  'Spice':     { temperature: 0.95, examples: [
    "keep texting me like that and you're going to have to follow through in person",
    "i'd tell you what i thought when i saw your last photo, but you haven't earned it yet",
    "careful. i'm exactly the kind of trouble your bio says you're looking for",
  ] },
```

- [ ] **Step 1.3:** `npm test -- tests/tones.test.ts` → PASS. Commit: `feat(backend): 11 dating tone library entries`

## Task 2: Backend — dating prompt family, CONTEXT parsing, mode param

**Files:** Modify `backend/src/services/llm.ts`, `backend/src/routes/reply.ts`, `backend/tests/llm.test.ts`, `backend/tests/reply.test.ts`

- [ ] **Step 2.1 — failing tests.** llm.test.ts additions:

```ts
describe('parseLlmOutput CONTEXT line', () => {
  it('parses an optional CONTEXT line', () => {
    const out = parseLlmOutput('CONTEXT: profile\nCONTACT: Maya\nSUMMARY: Maya, 28 — climbs\n1. hey one\n2. two\n3. three')
    expect(out.contextType).toBe('profile')
    expect(out.contactName).toBe('Maya')
    expect(out.replies).toHaveLength(3)
  })
  it('ignores invalid CONTEXT values and stays undefined without one', () => {
    expect(parseLlmOutput('CONTEXT: banana\n1. a').contextType).toBeUndefined()
    expect(parseLlmOutput('CONTACT: X\n1. a').contextType).toBeUndefined()
  })
})
describe('dating prompt family', () => {
  it('uses DATING identity for mode dating and chat identity otherwise', () => {
    const dating = buildSystemPromptForMode('dating', toneSpecFor('Tease', 'tease voice'), undefined)
    expect(dating).toContain('dating wingman')
    expect(dating).not.toContain('You are Replr. You generate human-like replies')
    const chat = buildSystemPromptForMode('chat', toneSpecFor('Friendly', 'friendly voice'), undefined)
    expect(chat).toContain('You are Replr. You generate human-like replies')
  })
})
```

reply.test.ts additions (generateReplies is already mocked):

```ts
  it('rejects an invalid mode', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest({ ...validBody, mode: 'wizard' }), env)
    expect(res.status).toBe(400)
  })
  it('passes mode through and returns contextType when present', async () => {
    const { env } = makeTestEnv()
    mockGenerateReplies.mockResolvedValueOnce({ replies: ['a','b','c'], summary: 's', contactName: 'Maya', contextType: 'profile', inputTokens: 1, outputTokens: 1, costUsd: 0 })
    const res = await app.request('/reply', jsonRequest({ ...validBody, mode: 'dating' }), env)
    expect(res.status).toBe(200)
    const json = await res.json() as { contextType?: string }
    expect(json.contextType).toBe('profile')
    expect(mockGenerateReplies.mock.calls[0][0].mode).toBe('dating')
  })
```

- [ ] **Step 2.2 — implement llm.ts.**
  1. New exported constant `DATING_IDENTITY` (full text):

```ts
const DATING_IDENTITY = `You are Replr's dating wingman. You write FOR the person using the app, TO the person shown in the screenshot — a dating-app profile or conversation (Tinder, Hinge, Bumble, and similar).

Mission: get responses, matches, numbers, dates. Every line must move toward one of those.

Non-negotiable rules:
- Anchor every line to at least one SPECIFIC detail from their profile or messages — a photo, a bio line, a prompt answer, an interest. If nothing is visible, use their name and the visible context. A line that could be sent to anyone is a failure.
- Never needy, never over-eager. Banned: "hey", "hi there", bare compliments about looks, exclamation-mark enthusiasm.
- Confidence is the register: assume value, never beg, never over-explain, leave room for them to chase.
- Once any rapport exists, assertive plan-making beats abstract interest: "thursday, that wine bar" not "we should hang out sometime".
- Bold and forward is good; manipulative is banned. Never neg, never degrade, never target insecurities. Challenge claims and situations, never the person's worth.
- Match the platform's register: a Hinge comment responds to a specific prompt; a Tinder opener can be bolder; mirror what the screenshot shows.
- Always write in the conversation's language, natively — never translate from English patterns.
- Each of the 3 options must take a distinct angle or energy.
- Plain text only. No markdown. Emoji only if their messages already use them.
- If the moment turns genuinely serious, drop the game and be human first.`
```

  2. New constant `DATING_DECISIONS`:

```ts
const DATING_DECISIONS = `First, classify what the screenshot shows, then follow that branch:
1. PROFILE — a dating profile (photos, bio, prompt answers; no message bubbles): write 3 openers / like-comments built on the profile's strongest one or two specifics. On Hinge, respond to a specific prompt or photo as a comment would.
2. EMPTY — a matched chat with no real exchange yet (match banner, empty or near-empty thread): write 3 pick-up lines — modern, self-aware, knowingly delivered; personalize with whatever IS visible (their name, the app, any visible prompt). Never dusty classics played straight.
3. CHAT — an ongoing conversation (RIGHT side = your user, LEFT side = the match, same as any chat): read the stage — banter, rapport, or ready-to-close — and write 3 replies that advance it. Build attraction and momentum; when rapport is clearly established, exactly one option should move toward the number or a concrete date.
Also: identify the match's first name; infer gender handling as usual for gendered languages; mirror their message length and energy, then lead slightly.`
```

  3. New format builder:

```ts
function buildDatingReplyFormat(count: number): string {
  return `Output EXACTLY ${count} replies — never fewer.
Plain text only — no markdown, no commentary.
Start with CONTEXT: on the very first line. Nothing before it.

CONTEXT: [profile | empty | chat — the case you classified]
CONTACT: [their first name exactly as shown. "Unknown" if not visible.]
SUMMARY: [one sentence — for profile: their essence (name, standout interests, hooks); for chats: topic and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}
```

  4. Generalize the system-prompt builder — add exported `buildSystemPromptForMode(mode, tone, aboutUser)` which uses `DATING_IDENTITY` when `mode === 'dating'`, else the existing `IDENTITY`, with the same tone-overlay + aboutUser composition (refactor `buildSystemPrompt` to delegate: `buildSystemPrompt(tone, about) === buildSystemPromptForMode('chat', tone, about)` — keep the old export so existing tests/imports stand).
  5. `ParsedOutput` gains `contextType?: 'profile' | 'empty' | 'chat'`; in `parseLlmOutput`, before the loop add a `context` matcher mirroring contact/summary: on `/^context:/i` set raw value; after the loop validate `['profile','empty','chat'].includes(v)` else leave undefined. Add `isBreak` coverage for `/^context:/i` so multi-line replies don't swallow it.
  6. `GenerateParams` gains `mode?: 'chat' | 'email' | 'dating'`. In `generateReplies`: when `mode === 'dating'` use `buildSystemPromptForMode('dating', …)` and a dating user prompt: `${buildContextBlock(summary, previousContext)}${DATING_DECISIONS}\n\n${buildDatingReplyFormat(REPLY_COUNT)}` (no chat reading-guide block — case 3 covers bubbles). Otherwise unchanged. `LlmResult` carries `contextType` through both call paths (`...parseLlmOutput(...)` already spreads it once ParsedOutput has the field).

- [ ] **Step 2.3 — implement reply.ts.** Destructure `mode` from the body; validate `mode === undefined || ['chat','email','dating'].includes(mode)` else 400 `{ error: 'Invalid mode. Must be one of: chat, email, dating' }`; pass `mode` into `generateReplies` (email path ignores it); spread `...(result.contextType ? { contextType: result.contextType } : {})` into the success JSON.

- [ ] **Step 2.4:** `npm run typecheck && npm test` → all green (existing suites unaffected: CONTEXT optional, mode optional). Commit: `feat(backend): dating prompt family — mode param, CONTEXT classification, separate identity`

## Task 3: iOS — Tone model: dating presets + availability

**Files:** Modify `Shared/Models/Tone.swift`

- [ ] **Step 3.1:** Add after `emailToneNames`:

```swift
    /// Tone names that can appear in the DATING keyboard row.
    /// 11 dating-specific presets + 4 everyday tones shared from chat.
    static let datingToneNames: Set<String> = [
        "Tease", "Smooth", "Bold", "Banter", "Intrigue", "Challenge",
        "Closer", "Revive", "Recovery", "Slow Burn", "Spice",
        // Shared everyday tones:
        "Natural", "Casual", "Chill", "Confident",
    ]

    /// Names that ONLY exist in dating mode (drives the Settings "Dating" section).
    static let datingOnlyToneNames: Set<String> = datingToneNames.subtracting(chatToneNames)

    /// Whether this tone is available for the dating keyboard row.
    var availableInDating: Bool {
        !isPreset || Tone.datingToneNames.contains(name)
    }
```

- [ ] **Step 3.2:** Append a new preset category block at the end of `presets` (existing `readTones()` migration auto-appends presets new to this version):

```swift
        // ── 7. Dating mode (hidden from chat/email; see datingToneNames) ────

        Tone(id: UUID(), name: "Tease",
             instruction: "Playful challenge and push-pull. Find the one detail in their profile or messages that's gently mockable and build the bit around it. Mock-accuse, never insult. Compliments arrive disguised as complaints. End somewhere they have to defend themselves — playfully.",
             blurb: "Playful push-pull — turns their profile into a bit.",
             isPreset: true),

        Tone(id: UUID(), name: "Smooth",
             instruction: "Charm that looks effortless. Compliments must be specific and earned from their profile — never about generic beauty. Interest should read as good taste, not eagerness. Unhurried sentences; let one line do the work of three.",
             blurb: "Effortless charm — compliments with craft.",
             isPreset: true),

        Tone(id: UUID(), name: "Bold",
             instruction: "Direct intent. Say what you want — the match, the drink, the date — without hedging or apology. Concrete plans beat abstract interest: name a day and a place when the conversation allows. Short. Confidence is the content.",
             blurb: "States intent, makes the plan.",
             isPreset: true),

        Tone(id: UUID(), name: "Banter",
             instruction: "Go for the laugh, anchored to THEIR specifics — their photos, bio lines, contradictions. Absurd scenarios, rankings, mock-petitions, callbacks. Commit fully to the bit. If the joke could be sent to anyone, start over.",
             blurb: "Committed humor built on their details.",
             isPreset: true),

        Tone(id: UUID(), name: "Intrigue",
             instruction: "Curiosity gaps. Refer to a thought you don't finish, an observation you withhold, a theory about them you won't explain yet. Shorter than expected. They should have to ask. Deliberate, never cold.",
             blurb: "Says less — opens loops they must close.",
             isPreset: true),

        Tone(id: UUID(), name: "Challenge",
             instruction: "Qualification energy: playful skepticism about compatibility — make them earn the next step. Challenge the claims in their profile. High standards worn lightly. Challenge the situation or the claim, never their worth or looks.",
             blurb: "Flips the frame — they convince you.",
             isPreset: true),

        Tone(id: UUID(), name: "Closer",
             instruction: "The close. Assume the yes; propose a concrete time and place drawn from the conversation or their profile. Move off-app naturally. One clean ask — no double-asking, no 'maybe sometime'.",
             blurb: "Locks in the number or the date.",
             isPreset: true),

        Tone(id: UUID(), name: "Revive",
             instruction: "The conversation died — restart it with zero guilt and zero reference to the silence being anyone's fault. Call back to an earlier thread or open a fresh specific angle. Make replying effortless. Never 'hey stranger', never ask why they vanished.",
             blurb: "Resurrects a dead conversation.",
             isPreset: true),

        Tone(id: UUID(), name: "Recovery",
             instruction: "Your last message didn't land or got left on read. Reset with self-aware humor — acknowledge lightly, never grovel or over-apologize. Pivot to a new specific topic. Unbothered is the whole game.",
             blurb: "Left on read? Reset the frame, unbothered.",
             isPreset: true),

        Tone(id: UUID(), name: "Slow Burn",
             instruction: "For matches worth investing in. Trade one layer of banter for one layer of genuine curiosity about their life. Specific questions over flirty volleys — but keep one ember of spark so it never reads platonic. Patience as confidence.",
             blurb: "The long game — depth with a spark.",
             isPreset: true),

        Tone(id: UUID(), name: "Spice",
             instruction: "Escalation when the energy is already mutual. Forward and suggestive — tension over explicitness; say less, imply more. Read the room hard: if their energy is not clearly matching, dial back to charm. Never crude openers to a cold profile.",
             blurb: "Turns up the heat — for mutual energy.",
             isPreset: true),
```

- [ ] **Step 3.3:** Build gate → commit: `feat(ios): 11 dating tone presets + dating availability sets`

## Task 4: iOS — third keyboard mode with persistence + tone filtering

**Files:** Modify `Shared/Constants.swift`, `Shared/AppGroupService.swift`, `ReplrKeyboard/Views/KeyboardView.swift`, `ReplrKeyboard/KeyboardViewController.swift`, `ReplrKeyboard/Views/IdlePanelView.swift`

- [ ] **Step 4.1 — Constants + AppGroupService:** key `selectedModeKey = "selected_mode"   // "chat" | "email" | "dating" — keyboard writes, intents read`; AppGroupService property (UserDefaults string, default `"chat"`, synchronize on set) named `selectedInputMode`.
- [ ] **Step 4.2 — KeyboardInputMode:** add `case dating`. In `ModeSegmentedControl`, add `modeButton(.dating, label: "Dating", icon: "heart.fill")` after Email with the same divider; in the mode-switch closure replace the email-only tone fallback with a general one:

```swift
model.inputMode = mode
AppGroupService.shared.selectedInputMode = {
    switch mode { case .chat: return "chat"; case .email: return "email"; case .dating: return "dating" }
}()
let available: (Tone) -> Bool = {
    switch mode { case .chat: return \.availableInChat; case .email: return \.availableInEmail; case .dating: return \.availableInDating }
}()
if !available(model.selectedTone) {
    // Dating prefers its flagship default; other modes take the first enabled tone.
    let fallback = (mode == .dating ? model.tones.first { $0.isEnabled && $0.name == "Tease" } : nil)
        ?? model.tones.first { $0.isEnabled && available($0) }
    if let fallback { model.selectedTone = fallback; model.onToneChanged?(fallback) }
}
```

  (Adapt to the existing closure style at the call site; key-path-as-closure needs `{ $0.availableInChat }` form.)
- [ ] **Step 4.3 — ToneRow filter:** replace the binary filter with a switch over `model.inputMode` → `availableInChat` / `availableInEmail` / `availableInDating`.
- [ ] **Step 4.4 — restore persisted mode:** in `KeyboardViewController.viewWillAppear` (near contact restore): map `AppGroupService.shared.selectedInputMode` → `model.inputMode` (unknown → `.chat`). Heights: `.dating` idle uses the chat height branch (`inputMode == .email ? 308 : 300` already defaults non-email to 300 — verify the switch covers `.dating` via default).
- [ ] **Step 4.5 — idle copy:** in `IdlePanelView`, find the chat-mode idle headline/subcopy and add the dating variant: headline "Screenshot a profile or a chat" / subline "Openers from profiles, replies from chats — Replr reads it." (exact insertion point chosen at execution; copy is fixed here).
- [ ] **Step 4.6:** Build gate → commit: `feat(ios): dating keyboard mode — segment, persistence, tone filtering + Tease fallback`

## Task 5: iOS — mode through the network layer, intents, dating memory

**Files:** Modify `Shared/ReplyService.swift`, `ReplrKeyboard/Views/KeyboardView.swift` (KeyboardModel paths), `Replr/Replr/Intents/GenerateReplyIntent.swift`, `Replr/Replr/Intents/QuickReplyIntent.swift`

- [ ] **Step 5.1 — ReplyService:** `ReplyRequest` gains `let mode: String`; `ReplyResponse`/`ReplyResult` gain `let contextType: String?`; `generateReplies(screenshot:tone:summary:previousContext:mode:)` with `mode: String = "chat"` threads it into the body (email request unchanged — no mode field needed; scroll path is gone). All three decode sites pass `contextType: decoded.contextType` (email path decodes nil naturally).
- [ ] **Step 5.2 — keyboard call sites:** `generateFromScreenshot` and `regenerateReplies` (non-email branch) pass `mode: inputMode == .dating ? "dating" : "chat"`. Memory gating in both becomes `if inputMode == .dating || AppGroupService.shared.memoryEnabled, let contactID = …` (dating always sends match memory; the fresh-capture contamination clear stays exactly as is).
- [ ] **Step 5.3 — intents:** both intents compute `let mode = AppGroupService.shared.selectedInputMode == "dating" ? "dating" : "chat"` and pass it to `generateReplies`. (Email persisted at intent time maps to chat — email mode is clipboard-text-only and never reaches the screenshot intents.)
- [ ] **Step 5.4:** Build gate → commit: `feat(ios): dating mode through ReplyService + intents; match memory always on in dating`

## Task 6: iOS — Settings "Dating" section

**Files:** Modify `Replr/Replr/Features/Tones/TonesView.swift`

- [ ] **Step 6.1 — view model split** (storage order = general presets, then dating presets, then custom — keyboard row order per mode follows each subset's order):

```swift
    var generalPresets: [Tone] { tones.filter { $0.isPreset && !Tone.datingOnlyToneNames.contains($0.name) } }
    var datingPresets: [Tone]  { tones.filter { $0.isPreset && Tone.datingOnlyToneNames.contains($0.name) } }

    private func stitch(general: [Tone], dating: [Tone]) {
        tones = general + dating + custom
        save()
    }
    func moveGeneralPresets(from source: IndexSet, to destination: Int) {
        var g = generalPresets; g.move(fromOffsets: source, toOffset: destination); stitch(general: g, dating: datingPresets)
    }
    func moveDatingPresets(from source: IndexSet, to destination: Int) {
        var d = datingPresets; d.move(fromOffsets: source, toOffset: destination); stitch(general: generalPresets, dating: d)
    }
```

  Replace `movePresets` usage: the existing "Presets" section iterates `vm.generalPresets` with `onMove(vm.moveGeneralPresets)`; add a new Section between Presets and Custom: header "Dating" + caption "Only shown in the keyboard's Dating mode", rows iterate `vm.datingPresets` with `onMove(vm.moveDatingPresets)`, same `PresetToneRow`. In `PresetToneRow.isDefaultPreset`, also mark `tone.name == "Tease"` as `default` (the dating default).
- [ ] **Step 6.2:** Build gate → commit: `feat(ios): Settings — separated Dating tones section`

## Task 7: Docs + full verification

**Files:** Modify `CLAUDE.md` (modes paragraph: three modes, dating prompt family + CONTEXT, dating-memory rule, mode persistence key), `docs/HANDOFF.md` (dating mode shipped → pre-launch list), memory file update at session level.

- [ ] **Step 7.1:** Doc edits per above.
- [ ] **Step 7.2:** Full gates: backend typecheck + full test suite; iOS build. Commit: `docs: dating mode in CLAUDE.md + HANDOFF`
- [ ] **Step 7.3 (user-triggered later):** deploy backend; production probe with a profile-like screenshot through `mode: "dating"`; TestFlight build.

---

## Self-review

- Spec coverage: §1 flow → Task 2 (DECISIONS branches); §2 UX → Tasks 4 (segment, persistence, fallback, idle copy, no new chips); §3 prompt family → Task 2; §4 tones → Tasks 1, 3, 6 (11 + shared 4 + Settings section, Tease default); §5 memory → Task 5.2; §7 edge cases → mode optional/validated (2.3), unknown CONTEXT → undefined (2.2.5); §8 testing → Tasks 1.1, 2.1 + build gates. Nudge chip: explicitly out (spec §6). ✓
- Type consistency: `contextType?: 'profile'|'empty'|'chat'` (TS) ↔ `contextType: String?` (Swift); `mode` string values identical across layers; `selectedInputMode` name used in Tasks 4.1/4.2/5.3. ✓
- No placeholders: all prompts, tones, and code blocks are complete; the two “locate at execution” points (ModeSegmentedControl closure style, IdlePanelView insertion) carry exact target content. ✓
