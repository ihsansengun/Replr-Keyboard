# Tone System Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tones genuinely shape replies — a layered prompt (base + additive tone overlay), a new "Natural" base tone, per-tone few-shot examples, and tone-aware temperature.

**Architecture:** New backend `tones.ts` library keyed by tone name (temperature + few-shot examples). `buildSystemPrompt` becomes BASE + additive overlay. The app sends the tone *name* so the backend can match the library; everything is backward-compatible (name optional → fallback). iOS adds a "Natural" base tone (first preset → the default).

**Tech Stack:** TypeScript / Hono / Cloudflare Workers (backend), Vitest (tests), SwiftUI / App Group (iOS).

**Spec:** `docs/superpowers/specs/2026-06-06-tone-system-design.md`

---

## File map
| File | Change |
|---|---|
| `backend/src/services/tones.ts` | **new** — `TONE_LIBRARY`, `ToneSpec`/`ResolvedTone`, `toneSpecFor()` |
| `backend/src/services/llm.ts` | `buildSystemPrompt` → base+overlay (takes `ResolvedTone`); reword energy rules + add rubric/read-the-room; thread `toneName`; set `temperature` |
| `backend/src/types/index.ts` | add optional `toneName` to `ReplyRequest` |
| `backend/src/routes/reply.ts` | read + pass `toneName` (both routes) |
| `backend/tests/llm.test.ts` | update `buildSystemPrompt` tests; add `toneSpecFor` + overlay + temperature tests |
| `Shared/Models/Tone.swift` | add "Natural" preset (first → default) |
| `Shared/ReplyService.swift` | send `toneName: tone.name` on the 3 request paths |

**Backend commands:** `cd backend && npm test` (Vitest), `npm run typecheck`. **iOS build (gate):**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr/Replr && xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | tail -5
```
SourceKit "No such module" diagnostics are FALSE POSITIVES — only `xcodebuild` counts. Use `iPhone 17`.

---

### Task 1: Backend — `tones.ts` library + `toneSpecFor` (TDD)

**Files:**
- Create: `backend/src/services/tones.ts`
- Create: `backend/tests/tones.test.ts`

- [ ] **Step 1: Write failing tests** — create `backend/tests/tones.test.ts`:
```ts
import { describe, it, expect } from 'vitest'
import { toneSpecFor, TONE_LIBRARY } from '../src/services/tones'

describe('toneSpecFor', () => {
  it('returns the library spec for a known tone (with examples + temperature)', () => {
    const r = toneSpecFor('Joker', 'the sent instruction')
    expect(r.temperature).toBeGreaterThan(0.9)
    expect(r.examples.length).toBeGreaterThan(0)
    expect(r.baseOnly).toBe(false)
    expect(r.voice).toBe('the sent instruction') // no voiceOverride this pass → uses the sent instruction
  })

  it('marks Natural as base-only with no overlay voice', () => {
    const r = toneSpecFor('Natural', 'whatever')
    expect(r.baseOnly).toBe(true)
    expect(r.voice).toBe('')
    expect(r.examples).toEqual([])
  })

  it('falls back for an unknown/custom tone: sent instruction, no examples, default temperature', () => {
    const r = toneSpecFor('My Custom Tone', 'be a pirate')
    expect(r.voice).toBe('be a pirate')
    expect(r.examples).toEqual([])
    expect(r.baseOnly).toBe(false)
    expect(r.temperature).toBeCloseTo(0.85)
  })

  it('falls back when toneName is undefined (older clients)', () => {
    const r = toneSpecFor(undefined, 'be warm')
    expect(r.voice).toBe('be warm')
    expect(r.temperature).toBeCloseTo(0.85)
  })

  it('gives structured tones a low temperature and bold tones a high one', () => {
    expect(toneSpecFor('Direct', 'x').temperature).toBeLessThan(0.7)
    expect(toneSpecFor('Seductive', 'x').temperature).toBeGreaterThan(0.9)
  })

  it('has a library entry for every shipped preset name', () => {
    const names = ['Natural','Friendly','Casual','Direct','Witty','Professional','Empathetic',
      'Enthusiastic','Concise','Formal','Dating','Joker','Passive Aggressive','Gen Z','Seductive','Sarcastic']
    for (const n of names) expect(TONE_LIBRARY[n], n).toBeDefined()
  })
})
```

- [ ] **Step 2: Run — expect FAIL** (`cd backend && npm test -- tests/tones.test.ts`) with "Cannot find module '../src/services/tones'".

- [ ] **Step 3: Implement** — create `backend/src/services/tones.ts`:
```ts
/** Per-tone tuning the backend layers on top of the sent instruction. */
export interface ToneSpec {
  temperature: number       // 0.0–1.0 (all providers accept this range)
  examples: string[]        // few-shot reply examples (flavor, not content); [] = none
  voiceOverride?: string    // optional backend-owned voice; absent → use the sent iOS instruction
  baseOnly?: boolean        // Natural: emit NO overlay (base only)
}

/** What the prompt builder consumes after resolving a request's tone. */
export interface ResolvedTone {
  voice: string             // overlay instruction; '' when baseOnly
  examples: string[]
  temperature: number
  baseOnly: boolean
}

const DEFAULT_TEMPERATURE = 0.85

/** Keyed by the tone's display name (matches Shared/Models/Tone.swift). Examples are
 *  FLAVOR — the model is told never to reuse their words. Priority 4 (Joker, Witty,
 *  Dating, Seductive) carry the most-crafted sets; the rest get first-pass sets (Task 7). */
export const TONE_LIBRARY: Record<string, ToneSpec> = {
  'Natural':      { temperature: 0.8,  examples: [], baseOnly: true },

  'Joker':        { temperature: 0.95, examples: [
    "oh you're 'fine'? that's the most threatening word in the english language, name a more iconic villain origin",
    "i was gonna say something charming here but you've emotionally disarmed me with a single emoji, well played",
    "breaking news: local girl claims she's 'busy', sources suspect she's lying down staring at the ceiling like the rest of us",
  ] },
  'Witty':        { temperature: 0.95, examples: [
    "incredible — you've managed to make 'running late' sound like a personality trait",
    "bold of you to assume i had plans that weren't just rearranging my whole week around this text",
    "a genuinely slow clap for that one",
  ] },
  'Dating':       { temperature: 0.9,  examples: [
    "you're trouble, i can already tell. the good kind, allegedly",
    "careful — keep being this interesting and i'll have to actually make an effort",
    "okay that was smooth. i'm choosing to be deeply suspicious of how smooth that was",
  ] },
  'Seductive':    { temperature: 0.95, examples: [
    "keep talking like that and you'll find out exactly how much i was paying attention",
    "i had a perfectly productive evening planned before you turned up in my notifications",
    "you say that like you don't already know what it does to me",
  ] },

  // First-pass sets filled in Task 7 — temperatures set now so §4 is complete.
  'Friendly':     { temperature: 0.85, examples: [] },
  'Casual':       { temperature: 0.85, examples: [] },
  'Direct':       { temperature: 0.6,  examples: [] },
  'Professional': { temperature: 0.6,  examples: [] },
  'Empathetic':   { temperature: 0.8,  examples: [] },
  'Enthusiastic': { temperature: 0.9,  examples: [] },
  'Concise':      { temperature: 0.6,  examples: [] },
  'Formal':       { temperature: 0.55, examples: [] },
  'Passive Aggressive': { temperature: 0.9, examples: [] },
  'Gen Z':        { temperature: 0.95, examples: [] },
  'Sarcastic':    { temperature: 0.95, examples: [] },
}

export function toneSpecFor(toneName: string | undefined, sentInstruction: string): ResolvedTone {
  const lib = toneName ? TONE_LIBRARY[toneName] : undefined
  if (!lib) {
    return { voice: sentInstruction, examples: [], temperature: DEFAULT_TEMPERATURE, baseOnly: false }
  }
  const baseOnly = lib.baseOnly ?? false
  return {
    voice: baseOnly ? '' : (lib.voiceOverride ?? sentInstruction),
    examples: lib.examples,
    temperature: lib.temperature,
    baseOnly,
  }
}
```

- [ ] **Step 4: Run — expect PASS** (`npm test -- tests/tones.test.ts`).

- [ ] **Step 5: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/tones.ts backend/tests/tones.test.ts
git commit -m "backend: tone library (temperature + few-shot examples) keyed by tone name

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Backend — layered `buildSystemPrompt` + reworded base rules (TDD)

**Files:**
- Modify: `backend/src/services/llm.ts` (IDENTITY, DECISIONS, `buildSystemPrompt`)
- Modify: `backend/tests/llm.test.ts` (the `buildSystemPrompt` describe block)

- [ ] **Step 1: Rewrite the `buildSystemPrompt` tests** — in `backend/tests/llm.test.ts`, replace the entire `describe('buildSystemPrompt', …)` block (currently asserting `ROLE: flirty`) with:
```ts
describe('buildSystemPrompt', () => {
  const overlayTone = (voice: string, examples: string[] = []) =>
    ({ voice, examples, temperature: 0.9, baseOnly: false })

  it('always includes the Replr identity and the "what makes a reply land" rubric', () => {
    const sys = buildSystemPrompt(overlayTone('flirty'))
    expect(sys).toContain('You are Replr')
    expect(sys).toContain('What makes a reply land')
  })

  it('layers the tone VOICE on top of the base', () => {
    const sys = buildSystemPrompt(overlayTone('be dryly funny'))
    expect(sys).toContain('VOICE')
    expect(sys).toContain('be dryly funny')
  })

  it('includes few-shot examples when the tone has them', () => {
    const sys = buildSystemPrompt(overlayTone('joke around', ['ha example one', 'ha example two']))
    expect(sys).toContain('Examples of this voice')
    expect(sys).toContain('ha example one')
    expect(sys).toContain('ha example two')
  })

  it('emits NO overlay for a base-only tone (Natural)', () => {
    const sys = buildSystemPrompt({ voice: '', examples: [], temperature: 0.8, baseOnly: true })
    expect(sys).toContain('You are Replr')
    expect(sys).not.toContain('VOICE')
  })

  it('includes the ABOUT-THE-USER block when aboutUser is provided, trimmed + capped', () => {
    const sys = buildSystemPrompt(overlayTone('casual'), '  ' + 'x'.repeat(500) + '  ')
    expect(sys).toContain('ABOUT THE USER')
    expect(sys).toContain('x'.repeat(300))
    expect(sys).not.toContain('x'.repeat(301))
  })

  it('omits the ABOUT block when aboutUser is empty/whitespace/undefined', () => {
    expect(buildSystemPrompt(overlayTone('casual'))).not.toContain('ABOUT THE USER')
    expect(buildSystemPrompt(overlayTone('casual'), '   ')).not.toContain('ABOUT THE USER')
  })
})
```

- [ ] **Step 2: Run — expect FAIL** (`npm test -- tests/llm.test.ts`) — old `buildSystemPrompt(string)` signature / missing rubric.

- [ ] **Step 3a: Reword IDENTITY** — in `backend/src/services/llm.ts`, in the `IDENTITY` template, change the line `- Match the reply length rhythm of the conversation` to:
```
- Match the conversation's language and length rhythm — but NOT its mood or restraint; your personality comes from the VOICE block below
```
Then, immediately **before** the line `Identity — read carefully:`, insert:
```
What makes a reply land:
- Specific to what they actually said — never generic
- Surprising beats safe — the obvious reply is the boring one
- It earns a reaction: a laugh, a "wait what", a reply back
- Zero clichés, zero AI-tells

Read the room: if the moment is genuinely serious — grief, distress, real conflict — drop the performance and be human first; the tone returns once the moment passes.

```

- [ ] **Step 3b: Reword DECISIONS** — in the `DECISIONS` template, change `2. Conversation energy → match it` to:
```
2. Conversation energy → read it, but let the VOICE lead your personality — do not mirror their restraint
```

- [ ] **Step 3c: Add the import + rewrite `buildSystemPrompt`** — at the top of `llm.ts` add:
```ts
import type { ResolvedTone } from './tones'
```
Replace the whole `buildSystemPrompt` function with:
```ts
/** Build the system prompt: BASE identity + an additive TONE OVERLAY (voice + examples),
 *  plus an optional user-profile block. The overlay is omitted for base-only tones. */
export function buildSystemPrompt(tone: ResolvedTone, aboutUser?: string): string {
  const parts = [IDENTITY]

  if (!tone.baseOnly && tone.voice) {
    let overlay = `VOICE — this is how you sound, layered on top of the rules above. Let the tone lead; read the room.\n${tone.voice}`
    if (tone.examples.length > 0) {
      overlay += `\nExamples of this voice (show the FLAVOR — never reuse their words or content):\n`
        + tone.examples.map(e => `- ${e}`).join('\n')
    }
    parts.push(overlay)
  }

  const about = aboutUser?.trim().slice(0, ABOUT_USER_MAX_CHARS)
  if (about) {
    parts.push(`ABOUT THE USER YOU'RE WRITING FOR (the right-side person — write in their voice):\n${about}`)
  }
  return parts.join('\n\n')
}
```
(Leave `ABOUT_USER_MAX_CHARS` as-is. `buildSystemPrompt`'s callers in the 3 generators are updated in Task 3 — the file will not typecheck until then; that's expected within this task's TDD loop, so run the targeted test file, not `typecheck`, here.)

- [ ] **Step 4: Run — expect PASS** for the `buildSystemPrompt` tests (`npm test -- tests/llm.test.ts -t buildSystemPrompt`). Other `llm.test.ts` suites (generateReplies) may fail to compile until Task 3 — that's fine; this step gates only the buildSystemPrompt tests.

- [ ] **Step 5: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/llm.ts backend/tests/llm.test.ts
git commit -m "backend: layered system prompt (base + additive tone overlay), reworded energy rules + rubric + read-the-room

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Backend — thread `toneName` + temperature through the generators (TDD)

**Files:**
- Modify: `backend/src/services/llm.ts` (param interfaces, 3 generators, `callLlm`/`callLlmText`)
- Modify: `backend/tests/llm.test.ts` (add temperature assertions)

- [ ] **Step 1: Add temperature tests** — append to the `describe('generateReplies', …)` block in `backend/tests/llm.test.ts`:
```ts
  it('passes a high temperature for a bold tone (Joker) to Claude', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: X\nSUMMARY: y\n1. a\n2. b\n3. c' }],
      usage: { input_tokens: 10, output_tokens: 5 },
    })
    await generateReplies({
      screenshotBase64: 'abc', tone: 'find the joke', toneName: 'Joker',
      model: 'claude-sonnet-4-6', anthropicKey: 'k', openaiKey: 'k',
    })
    expect(anthropicMessagesCreate).toHaveBeenCalledWith(
      expect.objectContaining({ temperature: 0.95 }))
  })

  it('passes the default temperature when no toneName is sent (older client)', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: X\nSUMMARY: y\n1. a\n2. b\n3. c' }],
      usage: { input_tokens: 10, output_tokens: 5 },
    })
    await generateReplies({
      screenshotBase64: 'abc', tone: 'be warm',
      model: 'claude-sonnet-4-6', anthropicKey: 'k', openaiKey: 'k',
    })
    expect(anthropicMessagesCreate).toHaveBeenCalledWith(
      expect.objectContaining({ temperature: 0.85 }))
  })
```

- [ ] **Step 2: Run — expect FAIL** (`npm test -- tests/llm.test.ts -t generateReplies`) — `toneName` not accepted / no temperature in the call.

- [ ] **Step 3a: Add `toneName?` to the 3 generator param interfaces** — in `llm.ts`, find each interface with `tone: string` (`GenerateParams`, `GenerateMultipleParams`, `GenerateEmailParams`) and add directly under each `tone: string` line:
```ts
  toneName?: string
```

- [ ] **Step 3b: Add `temperature` to the call-param interfaces** — find `LlmCallParams` and `LlmTextParams` and add to each:
```ts
  temperature: number
```

- [ ] **Step 3c: Resolve the spec in each of the 3 generators.** Add the import at the top of `llm.ts` (extend the Task-2 import):
```ts
import { toneSpecFor, type ResolvedTone } from './tones'
```
In **`generateReplies`**: change the destructure to include `toneName`, and replace `const system = buildSystemPrompt(tone, aboutUser)` with:
```ts
  const spec = toneSpecFor(toneName, tone)
  const system = buildSystemPrompt(spec, aboutUser)
```
and change the trailing `return callLlm({ system, user, images: [screenshotBase64], model, … })` to include `temperature: spec.temperature`. Do the **same three edits** in `generateRepliesFromMultiple` (destructure `toneName`, `const spec = toneSpecFor(toneName, tone)`, `buildSystemPrompt(spec, aboutUser)`, add `temperature: spec.temperature` to its `callLlm`) and in `generateRepliesFromEmail` (same, but its call is `callLlmText({ …, temperature: spec.temperature })`).

- [ ] **Step 3d: Apply the temperature in the provider calls.** In `callLlm`, destructure `temperature` from `params` (add it to the `const { … } = params` line), then add `temperature,` to BOTH `client.messages.create({ model, max_tokens: 2048, … })` (Anthropic) and `client.chat.completions.create({ model, max_completion_tokens: 2048, … })` (OpenAI/xAI/Google). Do the identical change in `callLlmText` (both its Anthropic and OpenAI `create` calls).

- [ ] **Step 4: Run — expect PASS** (`npm test -- tests/llm.test.ts`). All `llm.test.ts` suites green now.

- [ ] **Step 5: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/llm.ts backend/tests/llm.test.ts
git commit -m "backend: thread toneName + tone-aware temperature through all generators

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Backend — route + types accept and pass `toneName`

**Files:**
- Modify: `backend/src/types/index.ts`
- Modify: `backend/src/routes/reply.ts`

- [ ] **Step 1: Add to the request type** — in `backend/src/types/index.ts`, in `interface ReplyRequest`, add under `tone: string`:
```ts
  toneName?: string
```

- [ ] **Step 2: Thread through both routes** — in `backend/src/routes/reply.ts`:
  - In the `/` handler, add `toneName` to the destructure (`const { screenshotBase64, emailText, tone, toneName, summary, … }`), and add `toneName,` to BOTH the `generateRepliesFromEmail({ … })` and `generateReplies({ … })` argument objects.
  - In the `/scroll` handler, add `toneName?: string` to the body type, add `toneName` to the destructure, and add `toneName,` to the `generateRepliesFromMultiple({ … })` argument object.

- [ ] **Step 3: Typecheck + full test** — `cd backend && npm run typecheck` (clean) and `npm test` (all green, incl. `reply.test.ts`/`scroll.test.ts` which post without `toneName` → exercises the backward-compat fallback).

- [ ] **Step 4: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/types/index.ts backend/src/routes/reply.ts
git commit -m "backend: accept optional toneName on /reply and /reply/scroll

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: iOS — "Natural" base tone (first preset → default)

**Files:**
- Modify: `Shared/Models/Tone.swift`

- [ ] **Step 1: Add the preset** — in `Tone.swift`, make `Natural` the **first** element of `static let presets`, immediately after `[`:
```swift
        Tone(id: UUID(), name: "Natural",      instruction: "A clean, natural reply — well-written and human, no special personality.", isPreset: true),
```
(`readSelectedTone()` returns `Tone.presets[0]` for new users → Natural becomes the default; `readTones()` merges new presets in → existing users gain Natural without losing their selection. No other change needed.)

- [ ] **Step 2: Build** — run the iOS build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/Models/Tone.swift
git commit -m "iOS: add Natural base tone as the first preset (new default)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: iOS — `ReplyService` sends `toneName`

**Files:**
- Modify: `Shared/ReplyService.swift`

- [ ] **Step 1: Add `toneName` to the 3 request structs** — add `let toneName: String` directly under each `let tone: String`: in `struct ReplyRequest` (top of file), `struct ReplyEmailRequest`, and the nested `struct ScrollRequest` (inside `generateRepliesFromScroll`).

- [ ] **Step 2: Populate it on the 3 calls** — in each of `generateReplies`, `generateRepliesFromEmail`, `generateRepliesFromScroll`, in the body initializer add `toneName: tone.name,` directly under the existing `tone: tone.instruction,` line.

- [ ] **Step 3: Build** — run the iOS build command. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/ReplyService.swift
git commit -m "iOS: send tone name so the backend can match the tone library

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Backend — first-pass few-shot examples for the remaining 11 tones (content)

The priority 4 (Joker/Witty/Dating/Seductive) already have crafted sets (Task 1). Fill the remaining `examples: []` arrays in `TONE_LIBRARY` with a first-pass set. **Brief per tone = its iOS `instruction` in `Shared/Models/Tone.swift`**; the bar = the Joker set (specific, committed, never reuses their words). Dating-first flavor where it fits; 2–3 short lines each.

**Files:**
- Modify: `backend/src/services/tones.ts`

- [ ] **Step 1: Fill the arrays** — replace each remaining `examples: []` with these first-pass sets (refine later on device):
```ts
  'Friendly':     { temperature: 0.85, examples: [
    "honestly that just made my whole afternoon, tell me everything",
    "ok i love that for you, how are you feeling about it?",
  ] },
  'Casual':       { temperature: 0.85, examples: [
    "lol yeah i'm down, what time",
    "omg same. wanna just figure it out later",
  ] },
  'Direct':       { temperature: 0.6,  examples: [
    "yes. send the address and i'll be there",
    "can't do friday. saturday works",
  ] },
  'Professional': { temperature: 0.6,  examples: [
    "Happy to help — I'll review it today and send notes tomorrow.",
    "Thanks for flagging. Let's sync at 2pm to lock the details.",
  ] },
  'Empathetic':   { temperature: 0.8,  examples: [
    "that sounds genuinely exhausting, no wonder you're drained",
    "yeah, that would mess me up too. you don't have to have it figured out yet",
  ] },
  'Enthusiastic': { temperature: 0.9,  examples: [
    "wait this is amazing, i'm so happy for you",
    "ok i did not expect that and now i'm fully invested, tell me more",
  ] },
  'Concise':      { temperature: 0.6,  examples: [
    "works for me. 8pm?",
    "got it. on my way",
  ] },
  'Formal':       { temperature: 0.55, examples: [
    "Thank you for the update. I will confirm the details shortly.",
    "Understood — I appreciate you letting me know in advance.",
  ] },
  'Passive Aggressive': { temperature: 0.9, examples: [
    "no totally, it's fine, i didn't need that much notice anyway",
    "so glad you could fit me in, genuinely, no worries at all",
  ] },
  'Gen Z':        { temperature: 0.95, examples: [
    "not me lowkey obsessed with this plan, it's giving main character",
    "ok this is sending me, say less",
  ] },
  'Sarcastic':    { temperature: 0.95, examples: [
    "wow, a whole twenty minutes of effort, you must be exhausted",
    "no please, take your time, it's not like i was waiting or anything",
  ] },
```

- [ ] **Step 2: Run** — `cd backend && npm test -- tests/tones.test.ts` (still green; the "library entry for every preset" test now covers populated examples).

- [ ] **Step 3: Commit**
```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/tones.ts
git commit -m "backend: first-pass few-shot examples for the remaining 11 tones

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Verify end-to-end

- [ ] **Step 1: Backend** — `cd backend && npm run typecheck` (clean) and `npm test` (all suites green).
- [ ] **Step 2: iOS** — run the build command. Expect `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Manual reasoning check (no deploy — that's the user's call):**
  - A request **with** `toneName: "Joker"` → system prompt has BASE + a VOICE overlay + the 3 Joker examples; the Anthropic/OpenAI call carries `temperature: 0.95`.
  - A request with `toneName: "Natural"` → **no** overlay (base only), `temperature: 0.8`.
  - A request with **no** `toneName` (old client / a custom tone) → overlay = the sent instruction, no examples, `temperature: 0.85`. Nothing 500s.
- [ ] **Step 4: Hand back** — backend deploy (`npm run deploy`) + on-device tone trial ("would she laugh?" on Joker, then the rest) are the **user's** call. Commit any fix-ups (targeted `git add`).

---

## Self-review

**Spec coverage:**
- ✅ Layered prompt (base + additive overlay) → Task 2 (`buildSystemPrompt`)
- ✅ Reworded "match energy" → language+length only; rubric; read-the-room → Task 2 (IDENTITY + DECISIONS)
- ✅ `tones.ts` library keyed by name; `toneSpecFor` fallback; custom-tone graceful fallback → Task 1
- ✅ Examples for **all** presets (priority 4 crafted now, others first-pass) → Task 1 + Task 7
- ✅ Tone-aware temperature on all generators (none set before) → Task 1 (values) + Task 3 (applied)
- ✅ "Natural" base tone, first preset → default → Task 5
- ✅ iOS sends tone name → Task 6
- ✅ Backward-compatible (toneName optional → fallback) → Task 1 (`toneSpecFor`), Task 4 (optional in type), tested in Task 3 + Task 4
- ✅ TDD backend; `parseLlmOutput` tests untouched/green; typecheck clean; iOS build green → Tasks 1–8

**Placeholder scan:** none — every code/test step shows complete content; the "first-pass examples to refine on device" in Task 7 is concrete content + an explicit trial-then-filter decision from the spec, not an unfinished step.

**Type/name consistency:** `ToneSpec`/`ResolvedTone`/`toneSpecFor`/`TONE_LIBRARY` consistent across Tasks 1–3; `buildSystemPrompt(tone: ResolvedTone, aboutUser?)` defined in Task 2 and called with the resolved `spec` in Task 3; `temperature` added to `LlmCallParams`/`LlmTextParams` (Task 3b) and consumed in the `create()` calls (Task 3d); `toneName` flows iOS `tone.name` (Task 6) → request body → `ReplyRequest`/route (Task 4) → generator params (Task 3a) → `toneSpecFor` (Task 1). Library keys match the exact preset names in `Shared/Models/Tone.swift` (incl. "Natural", "Passive Aggressive", "Gen Z").
