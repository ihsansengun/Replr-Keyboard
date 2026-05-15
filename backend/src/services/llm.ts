import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import type { Model, Tier } from '../types'

const IDENTITY = `You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Each option must be distinct in angle or energy
- Match the reply length rhythm of the conversation`

const TONE_PROMPTS: Record<string, string> = {
  casual:       'Relaxed, warm, natural. Contractions always. Match their energy exactly.',
  friendly:     'Warm, positive, and genuine. Light energy without being over-the-top.',
  dating:       'Confident and genuine. Light wit when it fits. Never desperate, never try-hard.',
  professional: 'Clear, competent, respectful. Formal but not stiff.',
  formal:       'Polished and structured. Appropriate for official or high-stakes messages.',
  email:        'Structured email reply. Match the formality of the email. Clear, purposeful, no fluff.',
  bold:         'Short, direct, punchy. No filler. Gets to the point.',
  witty:        'Smart and playful. A touch of dry humor. Never forced.',
}

const DECISIONS = `Before generating replies, assess:
1. Language and cultural dialect → reply in the exact same register, not translated English
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the last message implies → address it
5. Whether to advance the conversation or simply respond
6. For dating contexts: where are they in the relationship?`

const PREMIUM_REPLY_COUNT = 5

export interface LlmResult {
  replies: string[]
  summary: string
}

/** Parse LLM output that starts with an optional SUMMARY: line followed by numbered replies. */
export function parseLlmOutput(text: string): LlmResult {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  let summary = ''
  const replies: string[] = []

  for (const line of lines) {
    if (!summary && line.startsWith('SUMMARY:')) {
      summary = line.replace(/^SUMMARY:\s*/i, '').trim()
    } else if (/^\d+[.)]\s/.test(line)) {
      replies.push(line.replace(/^\d+[.)]\s*/, '').trim())
    }
  }

  return { replies, summary }
}

interface LlmCallParams {
  system: string
  user: string
  images: string[]
  model: Model
  anthropicKey: string
  openaiKey: string
}

interface LlmTextParams {
  system: string
  user: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

async function callLlm(params: LlmCallParams): Promise<LlmResult> {
  const { system, user, images, model, anthropicKey, openaiKey } = params

  if (model === 'claude') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const imageContent = images.map(b64 => ({
      type: 'image' as const,
      source: { type: 'base64' as const, media_type: 'image/png' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: [...imageContent, { type: 'text', text: user }] }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
  }

  const client = new OpenAI({ apiKey: openaiKey })
  const imageContent = images.map(b64 => ({
    type: 'image_url' as const,
    image_url: { url: `data:image/png;base64,${b64}` }
  }))
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}

async function callLlmText(params: LlmTextParams): Promise<LlmResult> {
  const { system, user, model, anthropicKey, openaiKey } = params

  if (model === 'claude') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: user }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
  }

  const client = new OpenAI({ apiKey: openaiKey })
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}

export interface GenerateEmailParams {
  emailText: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  tier: Tier
  anthropicKey: string
  openaiKey: string
}

export interface GenerateParams {
  screenshotBase64: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  tier: Tier
  anthropicKey: string
  openaiKey: string
}

export interface GenerateMultipleParams {
  screenshots: string[]
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

function buildContextBlock(summary?: string, previousContext?: string): string {
  const parts: string[] = []
  if (previousContext) {
    parts.push(`CONVERSATION MEMORY (earlier in this same conversation):\n${previousContext}`)
  }
  if (summary) {
    parts.push(`CONVERSATION BACKGROUND (from user):\n${summary}`)
  }
  return parts.length > 0 ? parts.join('\n\n') + '\n\n' : ''
}

function buildReplyFormat(count: number): string {
  return `Output format — exactly this, no other text:
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, summary, previousContext, model, tier, anthropicKey, openaiKey } = params
  const count = tier === 'premium' ? PREMIUM_REPLY_COUNT : 3
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(count)}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey })
}

export async function generateRepliesFromMultiple(params: GenerateMultipleParams): Promise<LlmResult> {
  const { screenshots, tone, summary, previousContext, model, anthropicKey, openaiKey } = params
  const count = PREMIUM_REPLY_COUNT
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}The following screenshots show a conversation scrolled through from bottom to top. Read all of them together to understand the full context.

Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(count)}`

  return callLlm({ system, user, images: screenshots, model, anthropicKey, openaiKey })
}

export async function generateRepliesFromEmail(params: GenerateEmailParams): Promise<LlmResult> {
  const { emailText, tone, summary, previousContext, model, tier, anthropicKey, openaiKey } = params
  const count = tier === 'premium' ? PREMIUM_REPLY_COUNT : 3
  const toneInstruction = TONE_PROMPTS[tone.toLowerCase()] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}EMAIL TO REPLY TO:\n${emailText}\n\n${DECISIONS}\n\n${buildReplyFormat(count)}`

  return callLlmText({ system, user, model, anthropicKey, openaiKey })
}

/** Kept for any callers that still use the old signature — returns only replies. */
export function parseReplies(text: string): string[] {
  return parseLlmOutput(text).replies
}
