import { Hono } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import { checkRateLimit } from '../services/rateLimit'
import type { Env, ReplyRequest, Model } from '../types'

export const replyRoute = new Hono<{ Bindings: Env }>()

replyRoute.post('/', async (c) => {
  let body: Partial<ReplyRequest>
  try {
    body = await c.req.json<Partial<ReplyRequest>>()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }
  const { screenshotBase64, emailText, tone, summary, model, userId, transactionId } = body

  if ((!screenshotBase64 && !emailText) || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshotBase64 or emailText, tone, model, userId' }, 400)
  }

  if (model !== 'claude' && model !== 'gpt4o') {
    return c.json({ error: 'Invalid model. Must be "claude" or "gpt4o".' }, 400)
  }

  // TODO: validate transactionId against Apple App Store Server API before trusting premium tier
  const tier = transactionId ? 'premium' : 'free'
  const limit = parseInt(c.env.FREE_DAILY_LIMIT ?? '20', 10)
  const allowed = await checkRateLimit(c.env.RATE_LIMIT_KV, userId, tier, limit)

  if (!allowed) {
    return c.json({ error: 'Daily limit reached. Upgrade to premium for unlimited replies.' }, 429)
  }

  try {
    const replies = emailText
      ? await generateRepliesFromEmail({
          emailText, tone, summary, model, tier,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
      : await generateReplies({
          screenshotBase64: screenshotBase64!, tone, summary, model, tier,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
    if (replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies })
  } catch (err) {
    console.error('LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})

interface ScrollRequest {
  screenshots: string[]
  tone: string
  summary?: string
  model: Model
  userId: string
  transactionId?: string
}

replyRoute.post('/scroll', async (c) => {
  let body: Partial<ScrollRequest>
  try {
    body = await c.req.json<Partial<ScrollRequest>>()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshots, tone, model, userId, summary, transactionId } = body

  if (!Array.isArray(screenshots) || screenshots.length === 0 || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshots, tone, model, userId' }, 400)
  }

  if (model !== 'claude' && model !== 'gpt4o') {
    return c.json({ error: 'Invalid model. Must be "claude" or "gpt4o".' }, 400)
  }

  if (screenshots.length > 6) {
    return c.json({ error: 'Too many screenshots. Maximum 6 allowed.' }, 400)
  }

  // TODO: validate transactionId against Apple App Store Server API
  if (!transactionId) {
    return c.json({ error: 'Scroll capture requires premium.' }, 403)
  }

  const tier: 'premium' = 'premium'
  const limit = parseInt(c.env.FREE_DAILY_LIMIT ?? '20', 10)
  const allowed = await checkRateLimit(c.env.RATE_LIMIT_KV, userId, tier, limit)
  if (!allowed) {
    return c.json({ error: 'Daily limit reached. Upgrade to premium for unlimited replies.' }, 429)
  }

  try {
    const replies = await generateRepliesFromMultiple({
      screenshots,
      tone,
      summary,
      model,
      anthropicKey: c.env.ANTHROPIC_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    if (replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies })
  } catch (err) {
    console.error('Scroll LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
