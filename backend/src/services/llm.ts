import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import type { Model } from '../types'

const IDENTITY = `You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Each option must be distinct in angle or energy
- Match the reply length rhythm of the conversation`


const DECISIONS = `Before generating replies, assess:
1. Language and cultural dialect → reply in the exact same register, not translated English
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the last message implies → address it
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

export interface LlmResult {
  replies: string[]
  summary: string
  contactName: string
}

/** Parse LLM output: optional CONTACT: line, optional SUMMARY: line, numbered replies.
 *  Replies may span multiple lines (e.g. email bodies). */
export function parseLlmOutput(text: string): LlmResult {
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
      source: { type: 'base64' as const, media_type: 'image/png' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: [...imageContent, { type: 'text', text: user }] }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
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
    image_url: { url: `data:image/png;base64,${b64}` }
  }))
  const response = await client.chat.completions.create({
    model: apiModel,
    max_completion_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}

async function callLlmText(params: LlmTextParams): Promise<LlmResult> {
  const { system, user, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const { provider, apiModel } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: user }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
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
    max_completion_tokens: 1024,
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
    parts.push(`PREVIOUS CONVERSATIONS WITH THIS CONTACT (summaries of past sessions, oldest first):\n${previousContext}`)
  }
  if (summary) {
    parts.push(`CONTEXT NOTE FROM THE REPLY AUTHOR (not part of the chat — extra background typed by the person generating these replies to help you understand the situation):\n${summary}`)
  }
  return parts.length > 0 ? parts.join('\n\n') + '\n\n' : ''
}

function buildReplyFormat(count: number): string {
  return `Output format — exactly this, no other text:
CONTACT: [display name of the person you are replying TO, exactly as shown in the chat header. "Group: [name]" for group chats. "Unknown" if not visible.]
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, summary, previousContext, model, anthropicKey, openaiKey, xaiKey, googleKey } = params

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(REPLY_COUNT)}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey, xaiKey, googleKey })
}

export async function generateRepliesFromMultiple(params: GenerateMultipleParams): Promise<LlmResult> {
  const { screenshots, tone, summary, previousContext, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
  const count = REPLY_COUNT

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}The following screenshots show a conversation scrolled through from bottom to top. Read all of them together to understand the full context.

Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

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
