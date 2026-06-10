import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import type { Model } from '../types'
import { toneSpecFor, type ResolvedTone } from './tones'

const IDENTITY = `You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Each option must be distinct in angle or energy
- Match the conversation's language and length rhythm — but NOT its mood or restraint; your personality comes from the voice overlay below
- Always reply in the exact language of the conversation — never translate to or default to English
- CRITICAL — do NOT compose in English and translate. Think and write natively in the detected language from the start
- Use the idioms, expressions, and shortcuts a native speaker of that language would actually reach for — not English phrases wearing foreign words
- "Translated English" is the worst failure mode: grammatically correct but culturally hollow. A Turkish person says "Nice yıllara!" not "I hope you have a great birthday". An Italian says "In bocca al lupo!" not "Good luck". Always ask: what would a LOCAL person actually say here?

What makes a reply land:
- Specific to what they actually said — never generic
- Surprising beats safe — the obvious reply is the boring one
- It earns a reaction: a laugh, a "wait what", a reply back
- Zero clichés, zero AI-tells

Read the room: if the moment is genuinely serious — grief, distress, real conflict — drop the performance and be human first; the tone returns once the moment passes.

Identity — read carefully:
- You are writing FOR the person whose bubbles appear on the RIGHT
- You are writing TO the person whose bubbles appear on the LEFT
- These are two different people — never confuse them
- Your reply comes from the right-side person, addressed to the left-side person

Ignore these UI elements — they are metadata, not conversation content:
- Call logs (missed call, voice call, video call, duration in minutes)
- Message timestamps and delivery receipts (sent, delivered, read ticks)
- Reactions and emoji taps on messages
- Voice/audio message waveforms (you cannot hear them — do not guess their content)
- System messages ("you blocked this contact", "messages are encrypted", etc.)
Only use what was actually typed or written in message bubbles.`


const DECISIONS = `Before generating replies, assess:
1. Language → detect it, then think natively in it. Do NOT draft in English and translate — ask yourself "what would a local person actually say?" and write that, using real idioms and cultural expressions, not English patterns in foreign words
2. Conversation energy → read it, but let the VOICE lead your personality — do not mirror their restraint
3. Typical message length → stay consistent
4. What the most recent LEFT-side message implies → that is what you are replying to
5. Whether to advance the conversation or simply respond
6. Gender → infer the LEFT-side person's likely gender from their name, how the user addresses them, and the content; take the user's own gender from the ABOUT THE USER block (if provided). In grammatically-gendered languages get the gendered forms right for BOTH people; when a person's gender is genuinely unclear, prefer neutral phrasing over guessing. Reflect the real dynamic between the two (the flirt reads differently depending on who is writing to whom)
7. For dating contexts: where are they in the relationship?`

// ── Dating mode — a fully separate prompt family (never blended with chat) ──

const DATING_IDENTITY = `You are Replr's dating wingman. You write FOR the person using the app, TO the person shown in the screenshot — a dating-app profile or conversation (Tinder, Hinge, Bumble, and similar).

Mission: get responses, matches, numbers, dates. Every line must move toward one of those.

Non-negotiable rules:
- Anchor every line to at least one SPECIFIC detail from their profile or messages — a photo, a bio line, a prompt answer, an interest. If nothing is visible, use their name and the visible context. A line that could be sent to anyone is a failure.
- Never needy, never over-eager. Banned: "hey", "hi there", bare compliments about looks, exclamation-mark enthusiasm.
- Confidence is the register: assume value, never beg, never over-explain, leave room for them to chase.
- Once any rapport exists, assertive plan-making beats abstract interest: "thursday, that wine bar" not "we should hang out sometime".
- Bold and forward is good; manipulative is banned. Never neg, never degrade, never target insecurities. Challenge claims and situations, never the person's worth.
- Match the platform's register: a Hinge comment responds to a specific prompt; a Tinder opener can be bolder; mirror what the screenshot shows.
- Always write in the conversation's language, natively — never compose in English and translate. Use what a local person would actually say.
- Each of the 3 options must take a distinct angle or energy.
- Plain text only. No markdown. Emoji only if their messages already use them.
- If the moment turns genuinely serious, drop the game and be human first.

Sound like a person, never like AI:
- Text like someone typing on a phone, not composing prose. Contractions always. Fragments welcome.
- Dating apps are lowercase-casual by default — match the register of the voice examples; capitalize only if their own messages do.
- One thought per line. Never three balanced clauses. Never a sentence with the rhythm of ad copy.
- Banned tells: "I must say", "I have to admit", "certainly", "honestly," as a sentence opener, semicolons, perfectly parallel constructions, and summarizing their profile back at them.
- Imperfection is charm: a line can trail off, double down, or correct itself mid-thought.
- Final check: if a line couldn't plausibly be typed by a slightly overconfident human with one thumb, rewrite it shorter.`

const DATING_DECISIONS = `First, classify what the screenshot shows, then follow that branch:
1. PROFILE — a dating profile (photos, bio, prompt answers; no message bubbles): write 3 openers / like-comments built on the profile's strongest one or two specifics. On Hinge, respond to a specific prompt or photo the way a comment-with-like would.
2. EMPTY — a matched chat with no real exchange yet (match banner, empty or near-empty thread): write 3 pick-up lines — modern, self-aware, knowingly delivered; personalize with whatever IS visible (their name, the app, any visible prompt). Never dusty classics played straight.
3. CHAT — an ongoing conversation (RIGHT side = your user, LEFT side = the match, same as any chat): read the stage — banter, rapport, or ready-to-close — and write 3 replies that advance it. Build attraction and momentum; when rapport is clearly established, exactly one option should move toward the number or a concrete date.
Also: identify the match's first name; get gendered language right for both people in gendered languages; mirror their message length and energy, then lead slightly.`

function buildDatingReplyFormat(count: number): string {
  return `Output EXACTLY ${count} replies — never fewer.
Plain text only — no markdown, no commentary.
Start with CONTEXT: on the very first line. Nothing before it.

CONTEXT: [profile | empty | chat — the case you classified]
CONTACT: [their first name exactly as shown. "Unknown" if not visible.]
SUMMARY: [one sentence — for profile: their essence (name, standout interests, hooks); for chats: topic and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

/** Hard cap on the user-supplied profile text — keeps the system prompt bounded
 *  even if a client bypasses the app's 300-char field and posts a huge value. */
const ABOUT_USER_MAX_CHARS = 300

export type GenerationMode = 'chat' | 'email' | 'dating'

/** Build the system prompt for a mode: that mode's identity + an additive TONE
 *  OVERLAY (voice + examples), plus an optional user-profile block. Dating uses
 *  its own identity; chat and email share the base IDENTITY. */
export function buildSystemPromptForMode(mode: GenerationMode, tone: ResolvedTone, aboutUser?: string): string {
  const parts = [mode === 'dating' ? DATING_IDENTITY : IDENTITY]

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
    // Chat keeps its long-standing right-side framing (byte-identical prompt);
    // dating has no right-side bubbles on the profile branch.
    const frame = mode === 'dating'
      ? "ABOUT THE USER YOU'RE WRITING FOR (the person sending these lines — write in their voice)"
      : "ABOUT THE USER YOU'RE WRITING FOR (the right-side person — write in their voice)"
    parts.push(`${frame}:\n${about}`)
  }
  return parts.join('\n\n')
}

/** Back-compat: the chat/email system prompt builder. */
export function buildSystemPrompt(tone: ResolvedTone, aboutUser?: string): string {
  return buildSystemPromptForMode('chat', tone, aboutUser)
}

const REPLY_COUNT = 3

interface ModelResolution {
  provider: 'openai' | 'anthropic' | 'xai' | 'google'
  apiModel: string
  reasoningEffort?: 'low' | 'high'  // Gemini thinking level (Google path only). Omitted = provider default.
  temperatureLocked?: boolean       // true = model only allows the default temperature (e.g. gpt-5.5)
}

function resolveModel(model: Model): ModelResolution {
  switch (model) {
    case 'gpt-5.4':                  return { provider: 'openai',    apiModel: 'gpt-5.4' }
    case 'gpt-5.4-mini':             return { provider: 'openai',    apiModel: 'gpt-5.4-mini' }
    case 'gpt-5.5':                  return { provider: 'openai',    apiModel: 'gpt-5.5', temperatureLocked: true }
    case 'claude-sonnet-4-6':        return { provider: 'anthropic', apiModel: 'claude-sonnet-4-6' }
    case 'claude-opus-4-6':          return { provider: 'anthropic', apiModel: 'claude-opus-4-6' }
    case 'claude-opus-4-7':          return { provider: 'anthropic', apiModel: 'claude-opus-4-7', temperatureLocked: true }
    case 'claude-haiku-4-5':         return { provider: 'anthropic', apiModel: 'claude-haiku-4-5' }
    case 'grok-4':                   return { provider: 'xai',       apiModel: 'grok-4' }
    case 'grok-4.3':                 return { provider: 'xai',       apiModel: 'grok-4.3' }
    case 'gemini-3.1-pro-preview':   return { provider: 'google',    apiModel: 'gemini-3.1-pro-preview', reasoningEffort: 'high' }
    case 'gemini-3.1-pro-low':       return { provider: 'google',    apiModel: 'gemini-3.1-pro-preview', reasoningEffort: 'low' }
    case 'gemini-3-flash-preview':   return { provider: 'google',    apiModel: 'gemini-3-flash-preview', reasoningEffort: 'low' }
    case 'gemini-3.5-flash':         return { provider: 'google',    apiModel: 'gemini-3.5-flash',       reasoningEffort: 'low' }
    case 'gemini-3.1-flash-lite':    return { provider: 'google',    apiModel: 'gemini-3.1-flash-lite',  reasoningEffort: 'low' }
    case 'gemini-2.5-pro':           return { provider: 'google',    apiModel: 'gemini-2.5-pro' }
  }
}

interface ParsedOutput {
  replies: string[]
  summary: string
  contactName: string
  /** Dating-mode classification (CONTEXT: line). Undefined for chat/email. */
  contextType?: 'profile' | 'empty' | 'chat'
}

export interface LlmResult extends ParsedOutput {
  inputTokens: number
  outputTokens: number
  costUsd: number
}

// Cost per million tokens (USD) — sourced June 2026
const PRICING: Record<string, { inputPerM: number; outputPerM: number }> = {
  'claude-sonnet-4-6':      { inputPerM: 3.00,  outputPerM: 15.00 }, // platform.claude.com/docs/pricing
  'claude-opus-4-6':        { inputPerM: 5.00,  outputPerM: 25.00 }, // platform.claude.com/docs/pricing (was $15/$75 — Opus 4.1 legacy price, corrected 2026-06-06)
  'claude-opus-4-7':        { inputPerM: 5.00,  outputPerM: 25.00 }, // platform.claude.com/docs/pricing
  'claude-haiku-4-5':       { inputPerM: 1.00,  outputPerM: 5.00  }, // platform.claude.com/docs/pricing
  'gpt-5.4':                { inputPerM: 2.50,  outputPerM: 15.00 }, // openai.com/api/pricing
  'gpt-5.4-mini':           { inputPerM: 0.75,  outputPerM: 4.50  }, // openai.com/api/pricing
  'gpt-5.5':                { inputPerM: 5.00,  outputPerM: 30.00 }, // openai.com/api/pricing
  'grok-4':                 { inputPerM: 1.25,  outputPerM: 2.50  }, // docs.x.ai — grok-4 is an alias for grok-4.3, same price (corrected 2026-06-06)
  'grok-4.3':               { inputPerM: 1.25,  outputPerM: 2.50  }, // docs.x.ai
  'gemini-3.1-pro-preview': { inputPerM: 2.00,  outputPerM: 12.00 }, // ai.google.dev/gemini-api/docs/pricing
  'gemini-3-flash-preview': { inputPerM: 0.50,  outputPerM: 3.00  }, // ai.google.dev/gemini-api/docs/pricing
  'gemini-3.5-flash':       { inputPerM: 1.50,  outputPerM: 9.00  }, // ai.google.dev/gemini-api/docs/pricing
  'gemini-3.1-flash-lite':  { inputPerM: 0.25,  outputPerM: 1.50  }, // ai.google.dev/gemini-api/docs/pricing
  'gemini-2.5-pro':         { inputPerM: 1.25,  outputPerM: 10.00 }, // ai.google.dev/gemini-api/docs/pricing (≤200K tier)
}

function calcCost(apiModel: string, inputTokens: number, outputTokens: number): number {
  const p = PRICING[apiModel]
  if (!p) return 0
  return (inputTokens / 1_000_000) * p.inputPerM + (outputTokens / 1_000_000) * p.outputPerM
}

/** Parse LLM output: optional CONTACT: line, optional SUMMARY: line, numbered replies.
 *  Replies may span multiple lines (e.g. email bodies).
 *
 *  Robust against common provider formatting variations:
 *  - Markdown bold stripped (**1.** → 1.)
 *  - Optional space after number+punctuation (1.reply or 1. reply both match)
 *  - Leading/trailing asterisks stripped from reply text
 */
export function parseLlmOutput(text: string): ParsedOutput {
  const lines = text.split('\n')
  let summary = ''
  let contactName = ''
  let contextRaw = ''
  const replies: string[] = []

  // Strip markdown bold/italic from a line before pattern matching.
  const stripMarkdown = (s: string) => s.replace(/\*+/g, '').trim()

  // Matches numbered reply starters: "1. ", "1) ", "1." (no space), "1)"
  const isNumberedReply = (s: string) => /^\d+[.)]\s*\S/.test(s)
  // Also detect them in continuation-break logic
  const isBreak = (s: string) =>
    /^contact:/i.test(s) || /^summary:/i.test(s) || /^context:/i.test(s) || isNumberedReply(s)

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i].trim()
    const line = stripMarkdown(rawLine)
    if (!line) continue

    if (!contextRaw && /^context:/i.test(line)) {
      contextRaw = line.replace(/^context:\s*/i, '').trim().toLowerCase()
    } else if (!contactName && /^contact:/i.test(line)) {
      contactName = line.replace(/^contact:\s*/i, '').trim()
    } else if (!summary && /^summary:/i.test(line)) {
      summary = line.replace(/^summary:\s*/i, '').trim()
    } else if (isNumberedReply(line)) {
      // Strip the leading number + punctuation (with or without a trailing space)
      const replyLines = [line.replace(/^\d+[.)]\s*/, '').trim()]
      while (i + 1 < lines.length) {
        const nextRaw = lines[i + 1].trim()
        const next = stripMarkdown(nextRaw)
        if (isBreak(next)) break
        i++
        replyLines.push(next) // blank lines become '' — preserved as paragraph breaks
      }
      const reply = replyLines.join('\n').trimEnd()
      if (reply) replies.push(reply)
    }
  }

  const contextType = (['profile', 'empty', 'chat'] as const).find(v => v === contextRaw)
  return { replies, summary, contactName, ...(contextType ? { contextType } : {}) }
}

interface LlmCallParams {
  system: string
  user: string
  images: string[]
  model: Model
  temperature: number
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

interface LlmTextParams {
  system: string
  user: string
  model: Model
  temperature: number
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

async function callLlm(params: LlmCallParams): Promise<LlmResult> {
  const { system, user, images, model, temperature, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const { provider, apiModel, reasoningEffort, temperatureLocked } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const imageContent = images.map(b64 => ({
      type: 'image' as const,
      source: { type: 'base64' as const, media_type: 'image/jpeg' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 4096,
      // Newer Claude (Opus 4.7+) deprecates temperature — omit when the model locks it.
      ...(temperatureLocked ? {} : { temperature }),
      system,
      messages: [{ role: 'user', content: [...imageContent, { type: 'text', text: user }] }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    const inputTokens = response.usage.input_tokens
    const outputTokens = response.usage.output_tokens
    const costUsd = calcCost(apiModel, inputTokens, outputTokens)
    console.log(`[usage] ${apiModel} in=${inputTokens} out=${outputTokens} cost=$${costUsd.toFixed(6)}`)
    return {
      ...parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : ''),
      inputTokens, outputTokens, costUsd
    }
  }

  // xAI (Grok) and Google (Gemini) — both use OpenAI-compatible endpoints
  const apiKey = provider === 'xai'    ? (xaiKey    ?? '')
               : provider === 'google' ? (googleKey ?? '')
               : openaiKey
  const baseURL = provider === 'xai'    ? 'https://api.x.ai/v1'
                : provider === 'google' ? 'https://generativelanguage.googleapis.com/v1beta/openai/'
                : undefined
  const client = new OpenAI({ apiKey, ...(baseURL ? { baseURL } : {}) })
  const imageContent = images.map(b64 => ({
    type: 'image_url' as const,
    image_url: { url: `data:image/jpeg;base64,${b64}` }
  }))
  const response = await client.chat.completions.create({
    model: apiModel,
    // Token-cap param differs by provider: OpenAI's GPT-5.x REQUIRES max_completion_tokens (it now
    // rejects max_tokens); Gemini's OpenAI-compat endpoint ignores max_completion_tokens and wants
    // max_tokens; xAI accepts max_tokens. So pick per provider.
    ...(provider === 'openai' ? { max_completion_tokens: 4096 } : { max_tokens: 4096 }),
    // Some OpenAI reasoning models (e.g. gpt-5.5) reject any non-default temperature.
    ...(temperatureLocked ? {} : { temperature }),
    // Per-model thinking level (Gemini only — set in resolveModel). GPT/Grok share this
    // path but never set reasoningEffort, so they keep their own defaults. Gemini 3 Pro
    // rejects "medium" via the OpenAI-compat layer; only "low"/"high" are valid.
    ...(reasoningEffort ? { reasoning_effort: reasoningEffort } : {}),
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  } as any)
  const inputTokens = response.usage?.prompt_tokens ?? 0
  const outputTokens = response.usage?.completion_tokens ?? 0
  const costUsd = calcCost(apiModel, inputTokens, outputTokens)
  console.log(`[usage] ${provider}/${apiModel} usage=${JSON.stringify(response.usage)} in=${inputTokens} out=${outputTokens} cost=$${costUsd.toFixed(6)}`)
  return {
    ...parseLlmOutput(response.choices[0].message.content ?? ''),
    inputTokens, outputTokens, costUsd
  }
}

async function callLlmText(params: LlmTextParams): Promise<LlmResult> {
  const { system, user, model, temperature, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const { provider, apiModel, reasoningEffort, temperatureLocked } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 4096,
      // Newer Claude (Opus 4.7+) deprecates temperature — omit when the model locks it.
      ...(temperatureLocked ? {} : { temperature }),
      system,
      messages: [{ role: 'user', content: user }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    const inputTokens = response.usage.input_tokens
    const outputTokens = response.usage.output_tokens
    const costUsd = calcCost(apiModel, inputTokens, outputTokens)
    console.log(`[usage] ${apiModel} in=${inputTokens} out=${outputTokens} cost=$${costUsd.toFixed(6)}`)
    return {
      ...parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : ''),
      inputTokens, outputTokens, costUsd
    }
  }

  const apiKey = provider === 'xai'    ? (xaiKey    ?? '')
               : provider === 'google' ? (googleKey ?? '')
               : openaiKey
  const baseURL = provider === 'xai'    ? 'https://api.x.ai/v1'
                : provider === 'google' ? 'https://generativelanguage.googleapis.com/v1beta/openai/'
                : undefined
  const client = new OpenAI({ apiKey, ...(baseURL ? { baseURL } : {}) })
  const response = await client.chat.completions.create({
    model: apiModel,
    // OpenAI GPT-5.x requires max_completion_tokens; Gemini/xAI want max_tokens (see vision path).
    ...(provider === 'openai' ? { max_completion_tokens: 4096 } : { max_tokens: 4096 }),
    // Some OpenAI reasoning models (e.g. gpt-5.5) reject any non-default temperature.
    ...(temperatureLocked ? {} : { temperature }),
    ...(reasoningEffort ? { reasoning_effort: reasoningEffort } : {}),  // per-model Gemini thinking level (see callLlm)
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  } as any)
  const inputTokens = response.usage?.prompt_tokens ?? 0
  const outputTokens = response.usage?.completion_tokens ?? 0
  const costUsd = calcCost(apiModel, inputTokens, outputTokens)
  console.log(`[usage] ${provider}/${apiModel} usage=${JSON.stringify(response.usage)} in=${inputTokens} out=${outputTokens} cost=$${costUsd.toFixed(6)}`)
  return {
    ...parseLlmOutput(response.choices[0].message.content ?? ''),
    inputTokens, outputTokens, costUsd
  }
}

export interface GenerateEmailParams {
  emailText: string
  tone: string
  toneName?: string
  summary?: string
  previousContext?: string
  aboutUser?: string
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

export interface GenerateParams {
  screenshotBase64: string
  tone: string
  toneName?: string
  summary?: string
  previousContext?: string
  aboutUser?: string
  /** 'dating' selects the dating prompt family. Absent/chat → the classic chat prompts. */
  mode?: GenerationMode
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

function buildContextBlock(summary?: string, previousContext?: string): string {
  const parts: string[] = []
  if (previousContext) {
    parts.push(`MEMORY — PREVIOUS CONVERSATIONS WITH THIS CONTACT (oldest first, for context only):\n${previousContext}`)
  }
  if (summary) {
    parts.push(`REPLY DIRECTION — what the user wants to say or the angle they want to take (this is not part of the chat — it is an instruction from the person generating replies). Build your replies around this intent. If it conflicts with the obvious response, follow this direction:\n${summary}`)
  }
  return parts.length > 0 ? parts.join('\n\n') + '\n\n' : ''
}

function buildReplyFormat(count: number): string {
  return `Output EXACTLY ${count} replies — never fewer. Even simple conversations require all ${count} options.

Plain text only — no markdown, no bold, no bullet symbols, no extra commentary.
Start with CONTACT: on the very first line. Nothing before it.

CONTACT: [display name of the person you are replying TO, exactly as shown in the chat header. "Group: [name]" for group chats. "Unknown" if not visible.]
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, toneName, summary, previousContext, aboutUser, mode, model, anthropicKey, openaiKey, xaiKey, googleKey } = params

  const spec = toneSpecFor(toneName, tone)

  if (mode === 'dating') {
    const system = buildSystemPromptForMode('dating', spec, aboutUser)
    const user = `${buildContextBlock(summary, previousContext)}${DATING_DECISIONS}

${buildDatingReplyFormat(REPLY_COUNT)}`
    return callLlm({ system, user, images: [screenshotBase64], model, temperature: spec.temperature, anthropicKey, openaiKey, xaiKey, googleKey })
  }

  const system = buildSystemPrompt(spec, aboutUser)

  const user = `${buildContextBlock(summary, previousContext)}Reading guide — CRITICAL:
- RIGHT-side bubbles = YOUR USER (the person you are writing FOR — do not reply to these)
- LEFT-side bubbles = the other person (the person you are writing TO)
- Identify the most recent LEFT-side message — that is what you are replying to
- Never write a reply to a right-side message

${DECISIONS}

${buildReplyFormat(REPLY_COUNT)}`

  return callLlm({ system, user, images: [screenshotBase64], model, temperature: spec.temperature, anthropicKey, openaiKey, xaiKey, googleKey })
}

export async function generateRepliesFromEmail(params: GenerateEmailParams): Promise<LlmResult> {
  const { emailText, tone, toneName, summary, previousContext, aboutUser, model, anthropicKey, openaiKey, xaiKey, googleKey } = params

  const spec = toneSpecFor(toneName, tone)
  const system = buildSystemPrompt(spec, aboutUser)

  const user = `${buildContextBlock(summary, previousContext)}EMAIL TO REPLY TO:\n${emailText}\n\n${DECISIONS}\n\n${buildReplyFormat(REPLY_COUNT)}`

  return callLlmText({ system, user, model, temperature: spec.temperature, anthropicKey, openaiKey, xaiKey, googleKey })
}

/** Kept for any callers that still use the old signature — returns only replies. */
export function parseReplies(text: string): string[] {
  return parseLlmOutput(text).replies
}
