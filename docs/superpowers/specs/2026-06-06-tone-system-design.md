# Tone system overhaul — design

**Status:** spec for review · **Date:** 2026-06-06 · **Approach:** layered prompt (base + additive tone overlays) + per-tone few-shot examples

## Problem
Tones underwhelm — picking "Joker" doesn't produce replies that actually land (the bar: *funny enough that she laughs*). This is **not** a wiring bug: the app already sends each tone's full `instruction` (e.g. Joker → *"Find the joke… commit to the bit… Never explain the joke."*) and the backend uses it as `ROLE`. The problem is the **prompt around the tone**.

## Diagnosis (why tones underwhelm today)
1. **The base rules fight bold tones.** The prompt repeats *"match the conversation's energy / length / rhythm"* (IDENTITY + DECISIONS). On a dry/serious incoming message the model plays it safe — neutering Joker, Witty, Seductive.
2. **No examples.** The model is *told* to be funny but never *shown* a great Replr line. "She laughs" is calibrated with examples, not adjectives.
3. **The tone is one buried line** among ~20 other rules → under-weighted.
4. **No tone-aware creativity** — no `temperature` is set anywhere, and Joker shouldn't get the same latitude as Direct.

## Decisions (from brainstorming)
- **Context:** dating-first, still versatile. Priority tones: **Joker, Witty, Dating, Seductive.**
- **Boldness:** *tone leads, reads the room* — default boldly funny/flirty, let the tone drive the voice, but pull back when the moment is genuinely serious (bad news, conflict, distress).
- **Base/default tone:** a **new "Natural"** tone (personality-free base), made the default selection. Friendly stays a distinct mild-personality tone.
- **Examples scope this pass:** craft few-shot examples for the **priority 4** now; other presets get the re-framing + temperature, examples in a later pass.

## Design

### 1. Layered prompt: BASE + TONE OVERLAY (additive)
Restructure `buildSystemPrompt` so the system prompt is two explicit layers:

**BASE** — applies to *every* reply (this is what the "Natural" tone is, alone):
- Identity (write FOR the right-side person, TO the left-side), native-language/idiom rules, ignore-UI metadata — all kept.
- **Reworded energy rule:** *"Match their **language** and **length rhythm**. Do NOT mirror their mood or restraint — your personality comes from the tone below."* (The current "match energy/rhythm" lines that govern personality are the bug; they get scoped to language+length only.)
- **New "what makes a Replr line land" rubric** (short): be specific to what they actually said · surprising over safe · earns a reaction (a laugh, a "wait what", a reply) · zero clichés or AI-tells.
- **Read-the-room rule:** *"If the moment is genuinely serious — grief, distress, real conflict — drop the performance and be human first; the tone returns once the moment passes."*

**TONE OVERLAY** — appended after the base, clearly additive:
```
VOICE — this is how you sound, layered on top of the rules above. Let the tone lead; read the room.
<tone instruction — the iOS instruction by default; the backend library may override it>
Examples of this voice (show the FLAVOR — never reuse their words or content):
- <example 1>
- <example 2>
- <example 3>
```
For the **Natural** base tone the overlay is empty — base only.

### 2. New "Natural" base tone (iOS)
- Add `Tone(name: "Natural", instruction: "A clean, natural reply — well-written and human, no special personality.", isPreset: true)` as the **first** preset.
- Make it the **default selected tone** for new users (`readSelectedTone()` default). Existing users keep their saved selection.
- Backend treats `Natural` as **base-only** (empty overlay, moderate temperature).

### 3. Backend tone library (`backend/src/services/tones.ts`, new)
A lookup keyed by tone **name**. iOS is the source of truth for the voice words (shown in Settings); the library adds examples + temperature on top, with an *optional* override only when we deliberately want to sharpen a preset from the backend:
```ts
interface ToneSpec {
  temperature: number        // 0.0–1.0 creative latitude
  examples: string[]         // few-shot reply examples (flavor, not content); [] = none
  voiceOverride?: string     // optional backend-owned voice; when absent, use the sent iOS instruction
  baseOnly?: boolean         // Natural: emit NO overlay (base only)
}
export const TONE_LIBRARY: Record<string, ToneSpec>   // entries for presets we tune
export function toneSpecFor(name: string | undefined, sentInstruction: string): ResolvedTone
// overlay voice = baseOnly ? (none) : (voiceOverride ?? sentInstruction)
```
- The library holds an entry for **every preset we give a deliberate temperature** (all of them — see §4), **examples** for the priority 4 now, `baseOnly` for **Natural**. No `voiceOverride` is set in this pass (the iOS instructions are already decent → no divergence, no app update); the field exists so a future sharpening can ship by deploy.
- **Priority 4 get crafted, dating-first examples now.** Illustrative bar for **Joker** (examples are *flavor* — funny, committed, unexpected; the model must never reuse their words):
  - *"oh you're 'fine'? that's the most threatening word in the english language, name a more iconic villain origin"*
  - *"i was going to say something charming here but you've emotionally disarmed me with a single emoji, well played"*
  - *"breaking news: local girl says she's 'busy', sources suspect she's lying down staring at the ceiling like the rest of us"*

  Witty / Dating / Seductive get similarly-crafted sets (dry-clever / playful-confident / suggestive respectively), refined on device.
- **Other presets:** library entry with a `temperature` only, `examples: []`. (Examples added later.)
- **Custom user tones** (no library entry) → `toneSpecFor` returns the fallback: the **sent instruction** as voice, `examples: []`, the default medium temperature.

### 4. Tone-aware temperature
Each `ToneSpec` carries a 0.0–1.0 temperature (all providers accept this range): Joker/Witty/Sarcastic/Seductive/Gen Z high (~0.95), Friendly/Casual/Dating/Enthusiastic/Empathetic medium (~0.85), Natural ~0.8, Direct/Concise/Professional/Formal low (~0.6). Passed to every generator (currently none is set).

### 5. iOS: send the tone name
- `ReplyService` sends `toneName: tone.name` alongside the existing `tone: tone.instruction` (all 3 request paths: screenshot, scroll, email).
- Backend request types (`types/index.ts`) + routes (`reply.ts`) accept optional `toneName`. `buildSystemPrompt(toneInstruction, toneName, aboutUser)` resolves the spec via `toneSpecFor(toneName, toneInstruction)`.
- Presets match by name; custom tones fall back. **Backward-compatible:** a client that omits `toneName` still works (falls back to the instruction, no examples).

## Implementation touchpoints
| Area | File | Change |
|---|---|---|
| Tone library | `backend/src/services/tones.ts` (new) | `TONE_LIBRARY` + `toneSpecFor()`; priority-4 examples |
| Prompt | `backend/src/services/llm.ts` | base/overlay restructure of `buildSystemPrompt`; reworded energy rule + rubric + read-the-room; thread `toneName`; set `temperature` on all 4 generators |
| Request types | `backend/src/types/index.ts` | optional `toneName` on the reply request bodies |
| Routes | `backend/src/routes/reply.ts` | read + pass `toneName` |
| Base tone | `Shared/Models/Tone.swift` | add "Natural" preset (first) + make it default |
| Sender | `Shared/…/ReplyService.swift` | send `toneName` on the 3 request structs/calls |

## Testing
- Backend unit tests (Vitest): `buildSystemPrompt` includes the base + the overlay for a library tone (with examples) and base-only for `Natural`; `toneSpecFor` returns the library spec by name, the fallback for unknown/custom names; temperature is set per tone. Keep `parseLlmOutput` tests green.
- `npm run typecheck` clean.
- iOS build green; manual device test with real chats — **Joker is the bar** ("would she actually laugh?"), then Witty/Dating/Seductive.
- Backward-compat: a request without `toneName` still generates (fallback path).

## Out of scope (this pass)
- Few-shot examples for the non-priority presets (later pass).
- Moving the full tone definitions out of iOS / per-context (dating vs work) variants / an eval harness (Approach 3).
- Tone-chip UI changes; the relationship feature (parked).

## Success criteria
- Picking **Joker** yields replies that are genuinely, specifically funny on a real chat (not generic), while a serious incoming message still gets a human response (read-the-room).
- The **priority 4** each clearly express their voice; **Natural** is a clean grounded reply that respects the base.
- All tones iterate from the **backend** (deploy) — only the "send tone name" + "Natural" preset need an app build.
- Backward-compatible with existing clients.
