import { describe, it, expect, vi, beforeEach } from 'vitest'

// vi.mock is hoisted to the top by Vitest. Factory functions must NOT
// reference variables declared in the outer scope (they aren't initialised yet).
// We use vi.fn() inline here and retrieve the mocks via vi.mocked() below.

vi.mock('../src/services/llm', () => ({
  generateReplies: vi.fn(),
}))

// Import app and the mocked modules AFTER vi.mock calls.
import { app } from '../src/index'
import { generateReplies } from '../src/services/llm'
import { makeTestEnv, jsonRequest, todayKey } from './helpers'

const mockGenerateReplies = vi.mocked(generateReplies)

const validBody = {
  screenshotBase64: 'aGVsbG8=',
  tone: 'casual',
  model: 'claude-sonnet-4-6',
  userId: 'test-user-123',
}

describe('POST /reply', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGenerateReplies.mockResolvedValue({ replies: ['Reply 1', 'Reply 2', 'Reply 3'], summary: 'Test summary', contactName: 'Test Contact', inputTokens: 1000, outputTokens: 100, costUsd: 0.0045 })
  })

  it('returns replies for valid request', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest(validBody), env)
    expect(res.status).toBe(200)
    const json = await res.json() as { replies: string[], contactName: string }
    expect(json.replies).toEqual(['Reply 1', 'Reply 2', 'Reply 3'])
    expect(json.contactName).toBe('Test Contact')
  })

  it('returns 400 when screenshotBase64 is missing', async () => {
    const { env } = makeTestEnv()
    const { screenshotBase64: _, ...body } = validBody
    const res = await app.request('/reply', jsonRequest(body), env)
    expect(res.status).toBe(400)
  })

  it('returns 400 when userId is missing', async () => {
    const { env } = makeTestEnv()
    const { userId: _, ...body } = validBody
    const res = await app.request('/reply', jsonRequest(body), env)
    expect(res.status).toBe(400)
  })

  it('returns 400 when tone is missing', async () => {
    const { env } = makeTestEnv()
    const { tone: _, ...body } = validBody
    const res = await app.request('/reply', jsonRequest(body), env)
    expect(res.status).toBe(400)
  })

  it('returns 400 when model is missing', async () => {
    const { env } = makeTestEnv()
    const { model: _, ...body } = validBody
    const res = await app.request('/reply', jsonRequest(body), env)
    expect(res.status).toBe(400)
  })

  it('returns 400 for malformed JSON body', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'not valid json{',
    }, env)
    expect(res.status).toBe(400)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('Invalid JSON')
  })

  it('returns 400 for invalid model value', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest({ ...validBody, model: 'badmodel' }), env)
    expect(res.status).toBe(400)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('Invalid model')
  })

  it('returns 500 when LLM throws', async () => {
    const { env } = makeTestEnv()
    mockGenerateReplies.mockRejectedValueOnce(new Error('API down'))
    const res = await app.request('/reply', jsonRequest(validBody), env)
    expect(res.status).toBe(500)
  })

  it('accepts all valid model IDs', async () => {
    const { env } = makeTestEnv()
    const models = ['gpt-5.4', 'gpt-5.4-mini', 'gpt-5.5', 'claude-sonnet-4-6', 'claude-opus-4-6', 'grok-4', 'grok-4.3', 'gemini-3.1-pro-preview']
    for (const model of models) {
      const res = await app.request('/reply', jsonRequest({ ...validBody, model }), env)
      expect(res.status).toBe(200)
    }
  })

  // ── Access gate ────────────────────────────────────────────────────────────

  it('returns 429 for anonymous traffic past the per-IP daily limit', async () => {
    const { env } = makeTestEnv({}, { kv: new Map([[todayKey('ip:9.9.9.9'), '50']]) })
    const res = await app.request('/reply', jsonRequest(validBody, { ip: '9.9.9.9' }), env)
    expect(res.status).toBe(429)
  })

  it('rate-limits authenticated traffic by user, not IP', async () => {
    // IP counter is exhausted, but the authed user's own counter is fresh.
    const { env } = makeTestEnv({}, { kv: new Map([[todayKey('ip:9.9.9.9'), '50']]) })
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true, ip: '9.9.9.9' }), env)
    expect(res.status).toBe(200)
  })

  it('returns 401 for anonymous traffic when REQUIRE_AUTH is on', async () => {
    const { env } = makeTestEnv({ REQUIRE_AUTH: 'true' })
    const res = await app.request('/reply', jsonRequest(validBody), env)
    expect(res.status).toBe(401)
  })

  it('allows authenticated traffic when REQUIRE_AUTH is on', async () => {
    const { env } = makeTestEnv({ REQUIRE_AUTH: 'true' })
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(res.status).toBe(200)
  })

  // ── Server-side credit enforcement ─────────────────────────────────────────

  it('charges server-managed users and returns creditsRemaining', async () => {
    const { env, state } = makeTestEnv({}, { balance: 100 })
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(res.status).toBe(200)
    const json = await res.json() as { creditsRemaining?: number }
    expect(json.creditsRemaining).toBe(92)   // claude-sonnet-4-6 costs 8
    expect(state.balance).toBe(92)
  })

  it('returns 402 insufficient_credits when the balance cannot cover the model', async () => {
    const { env, state } = makeTestEnv({}, { balance: 3 })
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(res.status).toBe(402)
    const json = await res.json() as { error: string }
    expect(json.error).toBe('insufficient_credits')
    expect(state.balance).toBe(3)   // nothing charged
  })

  it('refunds the charge when the LLM call fails', async () => {
    const { env, state } = makeTestEnv({}, { balance: 100 })
    mockGenerateReplies.mockRejectedValueOnce(new Error('API down'))
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(res.status).toBe(500)
    expect(state.balance).toBe(100)   // 8 charged, 8 refunded
  })

  it('refunds the charge when the LLM returns no parseable replies', async () => {
    const { env, state } = makeTestEnv({}, { balance: 100 })
    mockGenerateReplies.mockResolvedValueOnce({ replies: [], summary: '', contactName: '', inputTokens: 0, outputTokens: 0, costUsd: 0 })
    const res = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(res.status).toBe(502)
    expect(state.balance).toBe(100)
  })

  it('does not charge anonymous or non-managed users', async () => {
    const { env: anonEnv, state: anonState } = makeTestEnv()
    const anonRes = await app.request('/reply', jsonRequest(validBody), anonEnv)
    expect(anonRes.status).toBe(200)
    const anonJson = await anonRes.json() as { creditsRemaining?: number }
    expect(anonJson.creditsRemaining).toBeUndefined()
    expect(anonState.balance).toBeNull()

    // Authenticated but no credits row yet (legacy client) → no enforcement.
    const { env: legacyEnv, state: legacyState } = makeTestEnv({}, { balance: null })
    const legacyRes = await app.request('/reply', jsonRequest(validBody, { auth: true }), legacyEnv)
    expect(legacyRes.status).toBe(200)
    const legacyJson = await legacyRes.json() as { creditsRemaining?: number }
    expect(legacyJson.creditsRemaining).toBeUndefined()
    expect(legacyState.balance).toBeNull()
  })

  it('omits the error detail for anonymous callers, includes it for authenticated ones', async () => {
    const { env } = makeTestEnv()
    mockGenerateReplies.mockRejectedValueOnce(new Error('provider exploded'))
    const anonRes = await app.request('/reply', jsonRequest(validBody), env)
    expect(anonRes.status).toBe(500)
    const anonJson = await anonRes.json() as { detail?: string }
    expect(anonJson.detail).toBeUndefined()

    mockGenerateReplies.mockRejectedValueOnce(new Error('provider exploded'))
    const authRes = await app.request('/reply', jsonRequest(validBody, { auth: true }), env)
    expect(authRes.status).toBe(500)
    const authJson = await authRes.json() as { detail?: string }
    expect(authJson.detail).toContain('provider exploded')
  })
})
