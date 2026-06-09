import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('../src/services/appstore', () => ({
  verifyTransactionJWS: vi.fn(),
}))

import { app } from '../src/index'
import { verifyTransactionJWS } from '../src/services/appstore'
import { makeTestEnv, jsonRequest, TEST_SESSION_TOKEN } from './helpers'

const mockVerify = vi.mocked(verifyTransactionJWS)

const VALID_PAYLOAD = {
  bundleId: 'Theory-of-Web.Replr',
  productId: 'com.ihsan.replr.credits.300',
  transactionId: 'tx-1',
  type: 'Consumable',
  environment: 'Production',
}

function get(path: string, auth = true) {
  const headers: Record<string, string> = {}
  if (auth) headers['Authorization'] = `Bearer ${TEST_SESSION_TOKEN}`
  return { method: 'GET', headers }
}

describe('/credits', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockVerify.mockResolvedValue(VALID_PAYLOAD)
  })

  it('requires auth on all endpoints', async () => {
    const { env } = makeTestEnv()
    expect((await app.request('/credits', get('/credits', false), env)).status).toBe(401)
    expect((await app.request('/credits/migrate', jsonRequest({ claimedBalance: 10 }), env)).status).toBe(401)
    expect((await app.request('/credits/redeem', jsonRequest({ jws: 'x' }), env)).status).toBe(401)
  })

  it('GET returns serverManaged:false with zero balance before any row exists', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/credits', get('/credits'), env)
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ balance: 0, serverManaged: false })
  })

  it('migrate adopts the claimed balance once, capped at 3000', async () => {
    const { env, state } = makeTestEnv()
    const res = await app.request('/credits/migrate', jsonRequest({ claimedBalance: 9999 }, { auth: true }), env)
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ balance: 3000, migrated: true })
    expect(state.balance).toBe(3000)

    // Second migrate is a no-op: existing balance wins, claim ignored.
    const res2 = await app.request('/credits/migrate', jsonRequest({ claimedBalance: 500 }, { auth: true }), env)
    expect(await res2.json()).toEqual({ balance: 3000, migrated: false })
    expect(state.balance).toBe(3000)
  })

  it('migrate treats a missing/invalid claim as zero', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/credits/migrate', jsonRequest({ claimedBalance: 'lots' }, { auth: true }), env)
    expect(await res.json()).toEqual({ balance: 0, migrated: true })
  })

  it('redeem verifies the JWS and grants pack credits', async () => {
    const { env, state } = makeTestEnv()
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ balance: 300, granted: true })
    expect(state.balance).toBe(300)
    expect(state.ledgerRefs.has('tx-1')).toBe(true)
  })

  it('redeem is idempotent per transactionId (StoreKit retry safety)', async () => {
    const { env, state } = makeTestEnv()
    await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    const res2 = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res2.status).toBe(200)
    expect(await res2.json()).toEqual({ balance: 300, granted: false })
    expect(state.balance).toBe(300)
  })

  it('redeem rejects an invalid JWS', async () => {
    const { env } = makeTestEnv()
    mockVerify.mockRejectedValueOnce(new Error('bad chain'))
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'forged' }, { auth: true }), env)
    expect(res.status).toBe(400)
  })

  it('redeem rejects a wrong bundleId', async () => {
    const { env } = makeTestEnv()
    mockVerify.mockResolvedValueOnce({ ...VALID_PAYLOAD, bundleId: 'com.evil.app' })
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res.status).toBe(400)
  })

  it('redeem rejects an unknown product', async () => {
    const { env } = makeTestEnv()
    mockVerify.mockResolvedValueOnce({ ...VALID_PAYLOAD, productId: 'com.ihsan.replr.credits.999999' })
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res.status).toBe(400)
  })

  it('redeem rejects sandbox transactions when ALLOW_SANDBOX_TRANSACTIONS is off', async () => {
    const { env } = makeTestEnv({ ALLOW_SANDBOX_TRANSACTIONS: 'false' })
    mockVerify.mockResolvedValueOnce({ ...VALID_PAYLOAD, environment: 'Sandbox' })
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res.status).toBe(400)
  })

  it('redeem accepts sandbox transactions when allowed (TestFlight)', async () => {
    const { env } = makeTestEnv({ ALLOW_SANDBOX_TRANSACTIONS: 'true' })
    mockVerify.mockResolvedValueOnce({ ...VALID_PAYLOAD, environment: 'Sandbox' })
    const res = await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    expect(res.status).toBe(200)
  })

  it('GET reflects the balance and serverManaged after a grant', async () => {
    const { env } = makeTestEnv()
    await app.request('/credits/redeem', jsonRequest({ jws: 'signed' }, { auth: true }), env)
    const res = await app.request('/credits', get('/credits'), env)
    expect(await res.json()).toEqual({ balance: 300, serverManaged: true })
  })
})
