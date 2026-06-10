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

/**
 * Tone library keyed by display name (must match Shared/Models/Tone.swift exactly).
 *
 * Examples are FLAVOR — the model is told never to reuse their words or content.
 * They show the VOICE, not a script. The model reads the actual conversation and
 * generates something new; the examples calibrate register and personality.
 *
 * Tone design principle: each tone maps to a distinct human psychological state —
 * not a style label, but an emotional posture someone is in when they need to reply.
 */
export const TONE_LIBRARY: Record<string, ToneSpec> = {

  // ── Base ──────────────────────────────────────────────────────────────────
  // Natural is the clean default. No personality overlay — base identity only.
  'Natural':      { temperature: 0.8, examples: [], baseOnly: true },

  // ── Default visible tones (ordered as they appear in the keyboard row) ────

  // "I want to be warm and make them feel good" — universal opener
  'Friendly':     { temperature: 0.85, examples: [
    "honestly that just made my whole afternoon, tell me everything",
    "ok i love that for you, how are you feeling about it?",
  ] },

  // "I'm texting like a close friend, not performing" — laid-back, mirrors their energy
  'Casual':       { temperature: 0.85, examples: [
    "lol yeah i'm down, what time",
    "omg same. wanna just figure it out later",
  ] },

  // "Light, a little teasing, effortlessly fun" — breezy mischief without committing to a full bit
  'Playful':      { temperature: 0.90, examples: [
    "oh interesting, so you're that kind of person 👀",
    "okay i like where this is going, tell me more",
    "you realise you've made it very difficult for me to pretend i'm not interested",
  ] },

  // "Say something clever they'll remember" — understatement, surprise, never explain the wit
  'Witty':        { temperature: 0.95, examples: [
    "incredible — you've managed to make 'running late' sound like a personality trait",
    "bold of you to assume i had plans that weren't just rearranging my whole week around this text",
    "a genuinely slow clap for that one",
  ] },

  // "Commit to making them laugh" — absurdist, unexpected callbacks, commit to the bit
  'Joker':        { temperature: 0.95, examples: [
    "oh you're 'fine'? that's the most threatening word in the english language, name a more iconic villain origin",
    "i was gonna say something charming here but you've emotionally disarmed me with a single emoji, well played",
    "breaking news: local girl claims she's 'busy', sources suspect she's lying down staring at the ceiling like the rest of us",
  ] },

  // "Show romantic interest without showing all your cards" — playful tension, don't give everything away
  'Flirty':       { temperature: 0.9, examples: [
    "you're trouble, i can already tell. the good kind, allegedly",
    "careful — keep being this interesting and i'll have to actually make an effort",
    "okay that was smooth. i'm choosing to be deeply suspicious of how smooth that was",
  ] },

  // "Turn the heat up — bold and forward" — explicitly sensual, specific, no hedging
  'Seductive':    { temperature: 0.95, examples: [
    "keep talking like that and you'll find out exactly how much i was paying attention",
    "i had a perfectly productive evening planned before you turned up in my notifications",
    "you say that like you don't already know what it does to me",
  ] },

  // "Make them feel heard, not advised" — reflect emotion first, never jump to solutions
  'Empathetic':   { temperature: 0.8, examples: [
    "that sounds genuinely exhausting, no wonder you're drained",
    "yeah, that would mess me up too. you don't have to have it figured out yet",
  ] },

  // "Reply from self-assurance, not eagerness" — grounded, doesn't over-explain, leaves them curious
  'Confident':    { temperature: 0.75, examples: [
    "sounds good. let's see how it goes",
    "i had a feeling you'd say that",
    "you're more interesting than i expected",
  ] },

  // "Just the answer, no fuss" — lead with the point, cut everything after that
  'Direct':       { temperature: 0.6, examples: [
    "yes. send the address and i'll be there",
    "can't do friday. saturday works",
  ] },

  // ── Email tones ────────────────────────────────────────────────────────────

  // "Professional but genuinely warm" — trusted advisor register, not corporate auto-reply
  'Warm Professional': { temperature: 0.8, examples: [
    "Thanks for flagging this — really helpful context. I'll take a look today and come back to you with thoughts.",
    "Appreciate the detail in your message. Here's where I see this going, and what I'd suggest as the next step.",
  ] },

  // "I need to decline, deliver difficult news, or push back without burning the bridge"
  'Diplomatic': { temperature: 0.75, examples: [
    "I can see why this feels frustrating, and I want to find something that works. Here's what I can do on my end — let me know if that gives you what you need.",
    "That's a fair point, and I've thought about it carefully. The reason I'm hesitant is X. What if we approached it this way instead?",
  ] },

  // "Firm, clear, no hedging — setting expectations or boundaries professionally"
  'Assertive': { temperature: 0.7, examples: [
    "I need the revised brief by Thursday to hit the deadline. If that's not possible, let's talk scope.",
    "My rate for this project is X. That reflects the timeline and deliverables as discussed. Let me know how you'd like to proceed.",
  ] },

  // ── Hidden by default (available in Settings → Tones) ─────────────────────

  'Sarcastic':    { temperature: 0.95, examples: [
    "wow, a whole twenty minutes of effort, you must be exhausted",
    "no please, take your time, it's not like i was waiting or anything",
  ] },

  'Passive Aggressive': { temperature: 0.9, examples: [
    "no totally, it's fine, i didn't need that much notice anyway",
    "so glad you could fit me in, genuinely, no worries at all",
  ] },

  'Gen Z':        { temperature: 0.95, examples: [
    "not me lowkey obsessed with this plan, it's giving main character",
    "ok this is sending me, say less",
  ] },

  'Enthusiastic': { temperature: 0.9, examples: [
    "wait this is amazing, i'm so happy for you",
    "ok i did not expect that and now i'm fully invested, tell me more",
  ] },

  'Concise':      { temperature: 0.6, examples: [
    "works for me. 8pm?",
    "got it. on my way",
  ] },

  'Professional': { temperature: 0.6, examples: [
    "Happy to help — I'll review it today and send notes tomorrow.",
    "Thanks for flagging. Let's sync at 2pm to lock the details.",
  ] },

  'Formal':       { temperature: 0.55, examples: [
    "Thank you for the update. I will confirm the details shortly.",
    "Understood — I appreciate you letting me know in advance.",
  ] },

  // ── Dating mode (separate family — never shown in chat/email) ─────────────
  // Voice instructions live in the iOS presets (Tone.swift §7. Dating); these
  // entries add temperature + flavor examples, exactly like the chat tones.
  // Style tones: how you sound. Scenario tones: the moments that happen.

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

  // ── Backward-compat alias ─────────────────────────────────────────────────
  // "Dating" was renamed to "Flirty" in the iOS app. Older clients still send
  // toneName: "Dating" — this keeps them working identically.
  'Dating':       { temperature: 0.9, examples: [
    "you're trouble, i can already tell. the good kind, allegedly",
    "careful — keep being this interesting and i'll have to actually make an effort",
    "okay that was smooth. i'm choosing to be deeply suspicious of how smooth that was",
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
