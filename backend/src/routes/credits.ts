import { Hono } from 'hono'
import type { Env } from '../types'
import { sessionMiddleware, SESSION_USER_ID_KEY, type SessionVariables } from '../middleware/session'
import { getBalance, grant } from '../services/credits'
import { verifyTransactionJWS } from '../services/appstore'
import { CREDIT_PACKS } from '../services/models'
import { ACTIVE_PAYWALL_EXPERIMENT, assignVariant } from '../services/paywall'

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

  // A/B telemetry: attribute the purchase to the variant this user is bucketed
  // into (recomputed server-side — same function the paywall served). Only on
  // first grant (StoreKit retries of the same transaction are not new sales),
  // and best-effort: a logging failure must never fail a paid redeem.
  if (granted) {
    try {
      const variant = await assignVariant(ACTIVE_PAYWALL_EXPERIMENT, userId)
      await c.env.DB
        .prepare('INSERT INTO paywall_events (id, user_id, experiment, variant, event, product_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), userId, ACTIVE_PAYWALL_EXPERIMENT.key, variant.name, 'purchase', payload.productId, Math.floor(Date.now() / 1000))
        .run()
    } catch (err) {
      console.error('paywall purchase event failed:', err)
    }
  }

  return c.json({ balance, granted })
})
