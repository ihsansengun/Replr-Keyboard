import { Hono } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import type { Env, Model } from '../types'

export const replyRoute = new Hono<{ Bindings: Env }>()

const VALID_MODELS: Model[] = ["gpt-5.4", "gpt-5.4-mini", "gpt-5.5", "claude-sonnet-4-6", "claude-opus-4-6", "grok-4", "grok-4.3", "gemini-3.1-pro-preview", "gemini-3.1-pro-low", "gemini-3-flash-preview", "gemini-3.5-flash", "gemini-3.1-flash-lite", "gemini-2.5-pro"]

replyRoute.post('/', async (c) => {
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshotBase64, emailText, tone, toneName, summary, previousContext, aboutUser, model, userId } =
    body as Record<string, string | undefined>

  if ((!screenshotBase64 && !emailText) || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshotBase64 or emailText, tone, model, userId' }, 400)
  }

  if (!VALID_MODELS.includes(model as Model)) {
    return c.json({ error: `Invalid model. Must be one of: ${VALID_MODELS.join(', ')}` }, 400)
  }

  try {
    const result = emailText
      ? await generateRepliesFromEmail({
          emailText, tone, toneName, summary, previousContext, aboutUser,
          model: model as Model,
          anthropicKey: c.env.ANTHROPIC_API_KEY, xaiKey: c.env.XAI_API_KEY, googleKey: c.env.GOOGLE_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
      : await generateReplies({
          screenshotBase64: screenshotBase64!,
          tone, toneName, summary, previousContext, aboutUser,
          model: model as Model,
          anthropicKey: c.env.ANTHROPIC_API_KEY, xaiKey: c.env.XAI_API_KEY, googleKey: c.env.GOOGLE_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName, inputTokens: result.inputTokens, outputTokens: result.outputTokens, costUsd: result.costUsd })
  } catch (err) {
    console.error('LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})

replyRoute.post('/scroll', async (c) => {
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshots, tone, toneName, model, userId, summary, previousContext, aboutUser } =
    body as { screenshots?: string[], tone?: string, toneName?: string, model?: string, userId?: string, summary?: string, previousContext?: string, aboutUser?: string }

  if (!Array.isArray(screenshots) || screenshots.length === 0 || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshots, tone, model, userId' }, 400)
  }

  if (!VALID_MODELS.includes(model as Model)) {
    return c.json({ error: `Invalid model. Must be one of: ${VALID_MODELS.join(', ')}` }, 400)
  }

  if (screenshots.length > 6) {
    return c.json({ error: 'Too many screenshots. Maximum 6 allowed.' }, 400)
  }

  try {
    const result = await generateRepliesFromMultiple({
      screenshots, tone, toneName, summary, previousContext, aboutUser,
      model: model as Model,
      anthropicKey: c.env.ANTHROPIC_API_KEY, xaiKey: c.env.XAI_API_KEY, googleKey: c.env.GOOGLE_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName, inputTokens: result.inputTokens, outputTokens: result.outputTokens, costUsd: result.costUsd })
  } catch (err) {
    console.error('Scroll LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
