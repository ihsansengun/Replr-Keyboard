import { Hono } from 'hono'
import type { Context } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import type { Env, Model } from '../types'
import { sessionMiddleware, SESSION_USER_ID_KEY, SessionVariables } from '../middleware/session'
import { checkRateLimit } from '../services/rateLimit'
import { VALID_MODELS, creditCostFor } from '../services/models'
import { getBalance, trySpend, grant } from '../services/credits'

export const replyRoute = new Hono<{ Bindings: Env; Variables: SessionVariables }>()

replyRoute.use('*', sessionMiddleware)

type ReplyContext = Context<{ Bindings: Env; Variables: SessionVariables }>

interface AccessResult {
  denied?: Response
  /** Credit balance when the user is server-managed; null otherwise. Fetched
   *  here once and reused by chargeCredits (saves a D1 read per request). */
  managedBalance: number | null
}

/** Auth + abuse gate shared by both reply endpoints. Anonymous traffic is keyed
 *  by IP so a caller can't reset their quota by rotating the client-invented
 *  userId. Three tiers:
 *    anonymous            → ANON_DAILY_LIMIT/IP   (their LLM calls are uncosted)
 *    signed-in, no ledger → FREE_DAILY_LIMIT/user (uncosted legacy clients)
 *    server-managed       → MANAGED_DAILY_LIMIT/user — every request costs
 *      purchased credits, so this is only a runaway-loop circuit breaker. */
async function enforceAccess(c: ReplyContext): Promise<AccessResult> {
  const authedUserID = c.get(SESSION_USER_ID_KEY)
  if (!authedUserID && c.env.REQUIRE_AUTH === 'true') {
    return { denied: c.json({ error: 'Sign in required. Update the Replr app and sign in.' }, 401), managedBalance: null }
  }
  const managedBalance = authedUserID ? await getBalance(c.env.DB, authedUserID) : null
  const key = authedUserID ? `user:${authedUserID}` : `ip:${c.req.header('CF-Connecting-IP') ?? 'unknown'}`
  const limit = managedBalance !== null
    ? parseInt(c.env.MANAGED_DAILY_LIMIT ?? '1000', 10)
    : authedUserID
      ? parseInt(c.env.FREE_DAILY_LIMIT, 10)
      : parseInt(c.env.ANON_DAILY_LIMIT ?? '50', 10)
  if (!(await checkRateLimit(c.env.RATE_LIMIT_KV, key, limit))) {
    return { denied: c.json({ error: 'Daily limit reached. Try again tomorrow.' }, 429), managedBalance }
  }
  return { managedBalance }
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

interface SpendResult {
  denied?: Response
  /** Credits charged (0 when the user isn't server-managed). */
  charged: number
  /** Balance after the charge; undefined when not server-managed. */
  creditsRemaining?: number
}

/** Charges the model's credit cost up-front for server-managed users (those with
 *  a credits row — created by the app via /credits/migrate or /redeem). Legacy
 *  and anonymous traffic passes through unchanged; rate limiting still applies.
 *  `managedBalance` comes from enforceAccess's lookup.
 *  Callers MUST refund via `refundIfCharged` on any failure after this. */
async function chargeCredits(c: ReplyContext, model: string, managedBalance: number | null): Promise<SpendResult> {
  const authedUserID = c.get(SESSION_USER_ID_KEY)
  if (!authedUserID || managedBalance === null) return { charged: 0 }

  const cost = creditCostFor(model)
  const newBalance = await trySpend(c.env.DB, authedUserID, cost)
  if (newBalance === null) {
    return { denied: c.json({ error: 'insufficient_credits' }, 402), charged: 0 }
  }
  return { charged: cost, creditsRemaining: newBalance }
}

/** Compensating refund for a charge whose generation failed. */
async function refundIfCharged(c: ReplyContext, charged: number): Promise<void> {
  const authedUserID = c.get(SESSION_USER_ID_KEY)
  if (!charged || !authedUserID) return
  try {
    await grant(c.env.DB, authedUserID, charged, 'refund', null)
  } catch (err) {
    console.error('Refund failed:', err)
  }
}

replyRoute.post('/', async (c) => {
  const access = await enforceAccess(c)
  if (access.denied) return access.denied

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

  const spend = await chargeCredits(c, model, access.managedBalance)
  if (spend.denied) return spend.denied

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
      await refundIfCharged(c, spend.charged)
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({
      replies: result.replies, summary: result.summary, contactName: result.contactName,
      inputTokens: result.inputTokens, outputTokens: result.outputTokens, costUsd: result.costUsd,
      ...(spend.creditsRemaining !== undefined ? { creditsRemaining: spend.creditsRemaining } : {}),
    })
  } catch (err) {
    console.error('LLM error:', err)
    await refundIfCharged(c, spend.charged)
    return llmErrorResponse(c, err)
  }
})

replyRoute.post('/scroll', async (c) => {
  const access = await enforceAccess(c)
  if (access.denied) return access.denied

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

  const spend = await chargeCredits(c, model, access.managedBalance)
  if (spend.denied) return spend.denied

  try {
    const result = await generateRepliesFromMultiple({
      screenshots, tone, toneName, summary, previousContext, aboutUser,
      model: model as Model,
      anthropicKey: c.env.ANTHROPIC_API_KEY, xaiKey: c.env.XAI_API_KEY, googleKey: c.env.GOOGLE_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    if (result.replies.length === 0) {
      await refundIfCharged(c, spend.charged)
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({
      replies: result.replies, summary: result.summary, contactName: result.contactName,
      inputTokens: result.inputTokens, outputTokens: result.outputTokens, costUsd: result.costUsd,
      ...(spend.creditsRemaining !== undefined ? { creditsRemaining: spend.creditsRemaining } : {}),
    })
  } catch (err) {
    console.error('Scroll LLM error:', err)
    await refundIfCharged(c, spend.charged)
    return llmErrorResponse(c, err)
  }
})
