import { Hono } from 'hono'
import { generateReplies } from '../services/llm'
import { checkRateLimit } from '../services/rateLimit'
import type { Env, ReplyRequest } from '../types'

export const replyRoute = new Hono<{ Bindings: Env }>()

replyRoute.post('/', async (c) => {
  let body: Partial<ReplyRequest>
  try {
    body = await c.req.json<Partial<ReplyRequest>>()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }
  const { screenshotBase64, tone, summary, model, userId, transactionId } = body

  if (!screenshotBase64 || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshotBase64, tone, model, userId' }, 400)
  }

  if (model !== 'claude' && model !== 'gpt4o') {
    return c.json({ error: 'Invalid model. Must be "claude" or "gpt4o".' }, 400)
  }

  const tier = transactionId ? 'premium' : 'free'
  const limit = parseInt(c.env.FREE_DAILY_LIMIT ?? '20', 10)
  const allowed = await checkRateLimit(c.env.RATE_LIMIT_KV, userId, tier, limit)

  if (!allowed) {
    return c.json({ error: 'Daily limit reached. Upgrade to premium for unlimited replies.' }, 429)
  }

  try {
    const replies = await generateReplies({
      screenshotBase64, tone, summary, model, tier,
      anthropicKey: c.env.ANTHROPIC_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    return c.json({ replies })
  } catch (err) {
    console.error('LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
