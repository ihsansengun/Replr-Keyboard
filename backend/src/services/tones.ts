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
