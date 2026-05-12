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
  dating:       'Confident and genuine. Light wit when it fits. Never desperate, never try-hard.',
  professional: 'Clear, competent, respectful. Formal but not stiff.',
  email:        'Structured reply. Appropriate formality read from the screenshot.',
  bold:         'Short, direct, punchy. No filler. Gets to the point.',
}

const DECISIONS = `Before generating replies, assess:
1. Language and cultural dialect → reply in the exact same register, not translated English
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the last message implies → address it
5. Whether to advance the conversation or simply respond
6. For dating contexts: where are they in the relationship?`

const PREMIUM_REPLY_COUNT = 5

export interface GenerateParams {
  screenshotBase64: string
  tone: string
  summary?: string
  model: Model
  tier: Tier
  anthropicKey: string
  openaiKey: string
}

export interface GenerateMultipleParams {
  screenshots: string[]
  tone: string
  summary?: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

interface LlmCallParams {
  system: string
  user: string
  images: string[]  // base64 PNGs
  model: Model
  anthropicKey: string
  openaiKey: string
}

async function callLlm(params: LlmCallParams): Promise<string[]> {
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
    return parseReplies(textBlock && 'text' in textBlock ? textBlock.text : '')
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
  return parseReplies(response.choices[0].message.content ?? '')
}

export async function generateReplies(params: GenerateParams): Promise<string[]> {
  const { screenshotBase64, tone, summary, model, tier, anthropicKey, openaiKey } = params
  const count = tier === 'premium' ? PREMIUM_REPLY_COUNT : 3
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [
    IDENTITY,
    `ROLE: ${toneInstruction}`,
    `Output exactly ${count} numbered reply options, nothing else.`,
  ].join('\n\n')

  const contextBlock = summary ? `CONVERSATION BACKGROUND:\n${summary}\n\n` : ''
  const user = `${contextBlock}Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

Reply format — output only this:
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey })
}

export async function generateRepliesFromMultiple(params: GenerateMultipleParams): Promise<string[]> {
  const { screenshots, tone, summary, model, anthropicKey, openaiKey } = params
  const count = PREMIUM_REPLY_COUNT
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [
    IDENTITY,
    `ROLE: ${toneInstruction}`,
    `Output exactly ${count} numbered reply options, nothing else.`,
  ].join('\n\n')

  const contextBlock = summary ? `CONVERSATION BACKGROUND:\n${summary}\n\n` : ''
  const user = `${contextBlock}The following screenshots show a conversation scrolled through from bottom to top. Read all of them together to understand the full context.

Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

Reply format — output only this:
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`

  return callLlm({ system, user, images: screenshots, model, anthropicKey, openaiKey })
}

export function parseReplies(text: string): string[] {
  return text
    .split('\n')
    .filter(line => /^\d+\./.test(line.trim()))
    .map(line => line.trim().replace(/^\d+[.)]\s*/, '').trim())
    .filter(Boolean)
}
