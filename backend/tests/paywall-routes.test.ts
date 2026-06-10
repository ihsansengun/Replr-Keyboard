import { describe, it, expect } from 'vitest'
import { app } from '../src/index'
import { makeTestEnv, jsonRequest, TEST_SESSION_TOKEN } from './helpers'
import { ACTIVE_PAYWALL_EXPERIMENT } from '../src/services/paywall'

function get(auth = true) {
  const headers: Record<string, string> = {}
  if (auth) headers['Authorization'] = `Bearer ${TEST_SESSION_TOKEN}`
  return { method: 'GET', headers }
}

describe('/paywall', () => {
  it('requires auth on both endpoints', async () => {
    const { env } = makeTestEnv()
    expect((await app.request('/paywall', get(false), env)).status).toBe(401)
    expect((await app.request('/paywall/event', jsonRequest({ event: 'impression' }), env)).status).toBe(401)
  })

  it('returns the assigned variant payload', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/paywall', get(), env)
    expect(res.status).toBe(200)
    const body = await res.json() as { experiment: string; variant: string; productIDs: string[]; badgeProductID: string | null }
    expect(body.experiment).toBe(ACTIVE_PAYWALL_EXPERIMENT.key)
    const variant = ACTIVE_PAYWALL_EXPERIMENT.variants.find(v => v.name === body.variant)
    expect(variant).toBeDefined()
    expect(body.productIDs).toEqual(variant!.productIDs)
    expect(body.badgeProductID).toBe(variant!.badgeProductID ?? null)
  })

  it('logs an impression with the server-computed variant', async () => {
    const { env, state } = makeTestEnv()
    const res = await app.request('/paywall/event', jsonRequest({ event: 'impression' }, { auth: true }), env)
    expect(res.status).toBe(200)
    expect(state.paywallEvents).toHaveLength(1)
    expect(state.paywallEvents[0].event).toBe('impression')
    expect(state.paywallEvents[0].experiment).toBe(ACTIVE_PAYWALL_EXPERIMENT.key)
    expect(state.paywallEvents[0].productId).toBeNull()
    // The variant is whatever the server assigned — a real variant name, not client input.
    expect(ACTIVE_PAYWALL_EXPERIMENT.variants.map(v => v.name)).toContain(state.paywallEvents[0].variant)
  })

  it('rejects unknown event types', async () => {
    const { env, state } = makeTestEnv()
    const res = await app.request('/paywall/event', jsonRequest({ event: 'purchase' }, { auth: true }), env)
    expect(res.status).toBe(400)
    expect(state.paywallEvents).toHaveLength(0)
  })
})
