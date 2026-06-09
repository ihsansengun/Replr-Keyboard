import { Hono } from 'hono'
import type { Context } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import type { Env, Model } from '../types'
import { sessionMiddleware, SESSION_USER_ID_KEY, SessionVariables } from '../middleware/session'
import { checkRateLimit } from '../services/rateLimit'
import { VALID_MODELS } from '../services/models'

export const replyRoute = new Hono<{ Bindings: Env; Variables: SessionVariables }>()

replyRoute.use('*', sessionMiddleware)

type ReplyContext = Context<{ Bindings: Env; Variables: SessionVariables }>

/** Auth + abuse gate shared by both reply endpoints. Returns an error Response,
 *  or null when the request may proceed. Anonymous traffic is keyed by IP so a
 *  caller can't reset their quota by rotating the client-invented userId. */
async function enforceAccess(c: ReplyContext): Promise<Response | null> {
  const authedUserID = c.get(SESSION_USER_ID_KEY)
  if (!authedUserID && c.env.REQUIRE_AUTH === 'true') {
    return c.json({ error: 'Sign in required. Update the Replr app and sign in.' }, 401)
  }
  const key = authedUserID ? `user:${authedUserID}` : `ip:${c.req.header('CF-Connecting-IP') ?? 'unknown'}`
  const limit = authedUserID
    ? parseInt(c.env.FREE_DAILY_LIMIT, 10)
    : parseInt(c.env.ANON_DAILY_LIMIT ?? '50', 10)
  if (!(await checkRateLimit(c.env.RATE_LIMIT_KV, key, limit))) {
    return c.json({ error: 'Daily limit reached. Try again tomorrow.' }, 429)
  }
  return null
}

/** 500 envelope: the raw provider error (`detail`) is only exposed to signed-in
 *  callers — the app's dev model-tester needs it; the open internet doesn't. */
function llmErrorResponse(c: ReplyContext, err: unknown): Response {
  const body: Record<string, string> = { error: 'Failed to generate replies. Please try again.' }
  if (c.get(SESSION_USER_ID_KEY)) {
    body.detail = String((err as { message?: string })?.message ?? err)
  }
  return c.json(body, 500)
}

replyRoute.post('/', async (c) => {
  const denied = await enforceAccess(c)
  if (denied) return denied

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
    return llmErrorResponse(c, err)
  }
})

replyRoute.post('/scroll', async (c) => {
  const denied = await enforceAccess(c)
  if (denied) return denied

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
    return llmErrorResponse(c, err)
  }
})
