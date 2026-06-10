import { Hono } from 'hono'
import type { Env } from '../types'
import { sessionMiddleware, SESSION_USER_ID_KEY, type SessionVariables } from '../middleware/session'
import { ACTIVE_PAYWALL_EXPERIMENT, assignVariant } from '../services/paywall'

export const paywallRoute = new Hono<{ Bindings: Env; Variables: SessionVariables }>()

paywallRoute.use('*', sessionMiddleware)

/** The caller's paywall variant. Pure recomputation — no assignment storage;
 *  the same function runs at impression and purchase logging time, so events
 *  are always attributed to the bucket the user actually saw. */
paywallRoute.get('/', async (c) => {
  const userId = c.get(SESSION_USER_ID_KEY)
  if (!userId) return c.json({ error: 'Sign in required' }, 401)

  const variant = await assignVariant(ACTIVE_PAYWALL_EXPERIMENT, userId)
  return c.json({
    experiment: ACTIVE_PAYWALL_EXPERIMENT.key,
    variant: variant.name,
    productIDs: variant.productIDs,
    badgeProductID: variant.badgeProductID ?? null,
    heroCopy: variant.heroCopy ?? null,
  })
})

/** Impression log. The client sends only `{event:'impression'}` — variant and
 *  experiment are computed server-side from the session, never trusted. */
paywallRoute.post('/event', async (c) => {
  const userId = c.get(SESSION_USER_ID_KEY)
  if (!userId) return c.json({ error: 'Sign in required' }, 401)

  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }
  if (body.event !== 'impression') return c.json({ error: 'Unknown event' }, 400)

  const variant = await assignVariant(ACTIVE_PAYWALL_EXPERIMENT, userId)
  await c.env.DB
    .prepare('INSERT INTO paywall_events (id, user_id, experiment, variant, event, product_id, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)')
    .bind(crypto.randomUUID(), userId, ACTIVE_PAYWALL_EXPERIMENT.key, variant.name, 'impression', Math.floor(Date.now() / 1000))
    .run()
  return c.json({ ok: true })
})
