import { Hono } from 'hono'
import type { Env } from '../types'
import { sessionMiddleware, SESSION_USER_ID_KEY, type SessionVariables } from '../middleware/session'
import { getBalance, grant } from '../services/credits'
import { verifyTransactionJWS } from '../services/appstore'
import { CREDIT_PACKS } from '../services/models'

// Matches the Sign in with Apple audience in routes/auth.ts (the app's bundle ID).
const APPLE_BUNDLE_ID = 'Theory-of-Web.Replr'

/** Cap on the one-time client-claimed legacy balance. The claim is client-trusted
 *  by necessity (the legacy balance only ever lived on-device); the cap bounds
 *  the damage a dishonest claim can do, and the endpoint is once-per-account. */
const MIGRATION_CAP = 3000

export const creditsRoute = new Hono<{ Bindings: Env; Variables: SessionVariables }>()

creditsRoute.use('*', sessionMiddleware)

creditsRoute.get('/', async (c) => {
  const userId = c.get(SESSION_USER_ID_KEY)
  if (!userId) return c.json({ error: 'Sign in required' }, 401)
  const balance = await getBalance(c.env.DB, userId)
  return balance === null
    ? c.json({ balance: 0, serverManaged: false })
    : c.json({ balance, serverManaged: true })
})

/** One-time adoption of the legacy client-side balance. Idempotent: once a
 *  credits row exists, the claimed value is ignored. */
creditsRoute.post('/migrate', async (c) => {
  const userId = c.get(SESSION_USER_ID_KEY)
  if (!userId) return c.json({ error: 'Sign in required' }, 401)

  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const claimedRaw = body.claimedBalance
  const claimed = typeof claimedRaw === 'number' && Number.isFinite(claimedRaw)
    ? Math.min(Math.max(Math.floor(claimedRaw), 0), MIGRATION_CAP)
    : 0

  const existing = await getBalance(c.env.DB, userId)
  if (existing !== null) return c.json({ balance: existing, migrated: false })

  const { balance } = await grant(c.env.DB, userId, claimed, 'migration', null)
  return c.json({ balance, migrated: true })
})

/** Verifies a StoreKit transaction JWS and grants the pack's credits.
 *  Deduped on transactionId via the ledger UNIQUE constraint, so StoreKit
 *  retries (Transaction.updates, unfinished replay) are safe to re-send. */
creditsRoute.post('/redeem', async (c) => {
  const userId = c.get(SESSION_USER_ID_KEY)
  if (!userId) return c.json({ error: 'Sign in required' }, 401)

  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const jws = body.jws
  if (typeof jws !== 'string' || !jws) return c.json({ error: 'Missing jws' }, 400)

  let payload
  try {
    payload = await verifyTransactionJWS(jws)
  } catch (err) {
    console.error('StoreKit JWS verification failed:', err)
    return c.json({ error: 'Invalid transaction' }, 400)
  }

  if (payload.bundleId !== APPLE_BUNDLE_ID) return c.json({ error: 'Wrong bundle id' }, 400)
  if (payload.environment !== 'Production' && c.env.ALLOW_SANDBOX_TRANSACTIONS !== 'true') {
    return c.json({ error: 'Sandbox transactions not accepted' }, 400)
  }
  const credits = CREDIT_PACKS[payload.productId ?? '']
  if (!credits) return c.json({ error: 'Unknown product' }, 400)
  if (!payload.transactionId) return c.json({ error: 'Missing transactionId' }, 400)

  const { balance, granted } = await grant(c.env.DB, userId, credits, 'purchase', payload.transactionId)
  return c.json({ balance, granted })
})
