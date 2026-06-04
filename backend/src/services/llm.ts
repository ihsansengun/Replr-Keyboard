import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import type { Model } from '../types'

const IDENTITY = `You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Each option must be distinct in angle or energy
- Match the reply length rhythm of the conversation
- Always reply in the exact language of the conversation — never translate to or default to English
- CRITICAL — do NOT compose in English and translate. Think and write natively in the detected language from the start
- Use the idioms, expressions, and shortcuts a native speaker of that language would actually reach for — not English phrases wearing foreign words
- "Translated English" is the worst failure mode: grammatically correct but culturally hollow. A Turkish person says "Nice yıllara!" not "I hope you have a great birthday". An Italian says "In bocca al lupo!" not "Good luck". Always ask: what would a LOCAL person actually say here?

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
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the most recent LEFT-side message implies → that is what you are replying to
5. Whether to advance the conversation or simply respond
6. For dating contexts: where are they in the relationship?`

const REPLY_COUNT = 3

interface ModelResolution {
  provider: 'openai' | 'anthropic' | 'xai' | 'google'
  apiModel: string
}

function resolveModel(model: Model): ModelResolution {
  switch (model) {
    case 'gpt-5.4':                  return { provider: 'openai',    apiModel: 'gpt-5.4' }
    case 'gpt-5.4-mini':             return { provider: 'openai',    apiModel: 'gpt-5.4-mini' }
    case 'gpt-5.5':                  return { provider: 'openai',    apiModel: 'gpt-5.5' }
    case 'claude-sonnet-4-6':        return { provider: 'anthropic', apiModel: 'claude-sonnet-4-6' }
    case 'claude-opus-4-6':          return { provider: 'anthropic', apiModel: 'claude-opus-4-6' }
    case 'grok-4':                   return { provider: 'xai',       apiModel: 'grok-4' }
    case 'grok-4.3':                 return { provider: 'xai',       apiModel: 'grok-4.3' }
    case 'gemini-3.1-pro-preview':   return { provider: 'google',    apiModel: 'gemini-3.1-pro-preview' }
  }
}

interface ParsedOutput {
  replies: string[]
  summary: string
  contactName: string
}

export interface LlmResult extends ParsedOutput {
  inputTokens: number
  outputTokens: number
  costUsd: number
}

// Cost per million tokens (USD) — sourced June 2026
const PRICING: Record<string, { inputPerM: number; outputPerM: number }> = {
  'claude-sonnet-4-6':      { inputPerM: 3.00,  outputPerM: 15.00 }, // anthropic.com
  'claude-opus-4-6':        { inputPerM: 15.00, outputPerM: 75.00 }, // anthropic.com
  'gpt-5.4':                { inputPerM: 2.50,  outputPerM: 15.00 }, // openai.com
  'gpt-5.4-mini':           { inputPerM: 0.75,  outputPerM: 4.50  }, // openai.com
  'gpt-5.5':                { inputPerM: 5.00,  outputPerM: 30.00 }, // openai.com
  'grok-4':                 { inputPerM: 3.00,  outputPerM: 15.00 }, // x.ai
  'grok-4.3':               { inputPerM: 1.25,  outputPerM: 2.50  }, // x.ai
  'gemini-3.1-pro-preview': { inputPerM: 2.00,  outputPerM: 12.00 }, // ai.google.dev
}

function calcCost(apiModel: string, inputTokens: number, outputTokens: number): number {
  const p = PRICING[apiModel]
  if (!p) return 0
  return (inputTokens / 1_000_000) * p.inputPerM + (outputTokens / 1_000_000) * p.outputPerM
}

/** Parse LLM output: optional CONTACT: line, optional SUMMARY: line, numbered replies.
 *  Replies may span multiple lines (e.g. email bodies). */
export function parseLlmOutput(text: string): ParsedOutput {
  const lines = text.split('\n')
  let summary = ''
  let contactName = ''
  const replies: string[] = []

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line) continue

    if (!contactName && /^contact:/i.test(line)) {
      contactName = line.replace(/^contact:\s*/i, '').trim()
    } else if (!summary && /^summary:/i.test(line)) {
      summary = line.replace(/^summary:\s*/i, '').trim()
    } else if (/^\d+[.)]\s/.test(line)) {
      // Collect this line and all continuation lines until next numbered item or header.
      // Preserve blank lines so multi-paragraph email replies keep their structure.
      const replyLines = [line.replace(/^\d+[.)]\s*/, '').trim()]
      while (i + 1 < lines.length) {
        const next = lines[i + 1].trim()
        if (/^contact:/i.test(next) || /^summary:/i.test(next) || /^\d+[.)]\s/.test(next)) break
        i++
        replyLines.push(next) // blank lines become '' — preserved as paragraph breaks
      }
      replies.push(replyLines.join('\n').trimEnd())
    }
  }

  return { replies, summary, contactName }
}

interface LlmCallParams {
  system: string
  user: string
  images: string[]
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

interface LlmTextParams {
  system: string
  user: string
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

async function callLlm(params: LlmCallParams): Promise<LlmResult> {
  const { system, user, images, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const { provider, apiModel } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const imageContent = images.map(b64 => ({
      type: 'image' as const,
      source: { type: 'base64' as const, media_type: 'image/jpeg' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 2048,
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
    max_completion_tokens: 2048,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  })
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
  const { system, user, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const { provider, apiModel } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 2048,
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
    max_completion_tokens: 2048,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  })
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
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

export interface GenerateParams {
  screenshotBase64: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
  xaiKey?: string
  googleKey?: string
}

export interface GenerateMultipleParams {
  screenshots: string[]
  tone: string
  summary?: string
  previousContext?: string
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
  return `You MUST output exactly ${count} replies — no more, no fewer. Even if the conversation is simple, always produce all ${count} options.

Output format — exactly this structure, no other text before or after:
CONTACT: [display name of the person you are replying TO, exactly as shown in the chat header. "Group: [name]" for group chats. "Unknown" if not visible.]
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, summary, previousContext, model, anthropicKey, openaiKey, xaiKey, googleKey } = params

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}Reading guide — CRITICAL:
- RIGHT-side bubbles = YOUR USER (the person you are writing FOR — do not reply to these)
- LEFT-side bubbles = the other person (the person you are writing TO)
- Identify the most recent LEFT-side message — that is what you are replying to
- Never write a reply to a right-side message

${DECISIONS}

${buildReplyFormat(REPLY_COUNT)}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey, xaiKey, googleKey })
}

export async function generateRepliesFromMultiple(params: GenerateMultipleParams): Promise<LlmResult> {
  const { screenshots, tone, summary, previousContext, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const count = REPLY_COUNT

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}The following screenshots show a conversation scrolled through from bottom to top. Read all of them together to understand the full context.

Reading guide — CRITICAL:
- RIGHT-side bubbles = YOUR USER (the person you are writing FOR — do not reply to these)
- LEFT-side bubbles = the other person (the person you are writing TO)
- Identify the most recent LEFT-side message — that is what you are replying to
- Never write a reply to a right-side message

${DECISIONS}

${buildReplyFormat(count)}`

  return callLlm({ system, user, images: screenshots, model, anthropicKey, openaiKey, xaiKey, googleKey })
}

export async function generateRepliesFromEmail(params: GenerateEmailParams): Promise<LlmResult> {
  const { emailText, tone, summary, previousContext, model, anthropicKey, openaiKey, xaiKey, googleKey } = params

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}EMAIL TO REPLY TO:\n${emailText}\n\n${DECISIONS}\n\n${buildReplyFormat(REPLY_COUNT)}`

  return callLlmText({ system, user, model, anthropicKey, openaiKey, xaiKey, googleKey })
}

/** Kept for any callers that still use the old signature — returns only replies. */
export function parseReplies(text: string): string[] {
  return parseLlmOutput(text).replies
}
