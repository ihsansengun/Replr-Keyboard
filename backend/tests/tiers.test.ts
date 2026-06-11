import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('../src/services/llm', () => ({
  generateReplies: vi.fn(),
}))

import { app } from '../src/index'
import { generateReplies } from '../src/services/llm'
import { makeTestEnv, jsonRequest } from './helpers'

const mockGenerateReplies = vi.mocked(generateReplies)

const tierBody = (model: string) => ({
  screenshotBase64: 'aGVsbG8=',
  tone: 'casual',
  toneName: 'Casual',
  userId: 'test-user-123',
  model,
})

// Quality tiers: the app sends 'balanced'/'max' as `model`; the server resolves
// which vendor model that means and charges the TIER's price. Repointing a tier
// to a different vendor is a backend-only deploy and must never change pricing.
describe('quality tiers (balanced/max)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGenerateReplies.mockResolvedValue({
      replies: ['r1', 'r2', 'r3'], summary: 's', contactName: 'c',
      inputTokens: 1, outputTokens: 1, costUsd: 0,
    })
  })

  it('resolves balanced to its underlying vendor model', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest(tierBody('balanced')), env)
    expect(res.status).toBe(200)
    expect(mockGenerateReplies).toHaveBeenCalledTimes(1)
    expect(mockGenerateReplies.mock.calls[0][0].model).toBe('gemini-3.5-flash')
  })

  it('resolves max to its underlying vendor model', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest(tierBody('max')), env)
    expect(res.status).toBe(200)
    expect(mockGenerateReplies.mock.calls[0][0].model).toBe('gemini-3.1-pro-preview')
  })

  it('charges the tier price: max = 6 credits', async () => {
    const { env } = makeTestEnv({}, { balance: 100 })
    const res = await app.request('/reply', jsonRequest(tierBody('max'), { auth: true }), env)
    expect(res.status).toBe(200)
    const json = await res.json() as { creditsRemaining: number }
    expect(json.creditsRemaining).toBe(94)
  })

  it('charges the tier price: balanced = 4 credits', async () => {
    const { env } = makeTestEnv({}, { balance: 100 })
    const res = await app.request('/reply', jsonRequest(tierBody('balanced'), { auth: true }), env)
    expect(res.status).toBe(200)
    const json = await res.json() as { creditsRemaining: number }
    expect(json.creditsRemaining).toBe(96)
  })

  it('rejects unknown models with tiers listed first', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest(tierBody('gpt-9000')), env)
    expect(res.status).toBe(400)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('balanced')
  })

  it('keeps raw vendor ids valid (dev mode sends them)', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/reply', jsonRequest(tierBody('claude-sonnet-4-6')), env)
    expect(res.status).toBe(200)
    expect(mockGenerateReplies.mock.calls[0][0].model).toBe('claude-sonnet-4-6')
  })

  it('GET /config serves tiers first as the production catalog', async () => {
    const res = await app.request('/config', {}, {})
    expect(res.status).toBe(200)
    const body = await res.json() as {
      defaultModel: string
      models: Array<{ id: string; label: string; creditCost: number; production: boolean }>
    }
    expect(body.defaultModel).toBe('balanced')
    expect(body.models[0]).toEqual({ id: 'balanced', label: 'Balanced', creditCost: 4, production: true })
    expect(body.models[1]).toEqual({ id: 'max', label: 'Max', creditCost: 6, production: true })
    // The raw vendor models behind the tiers are dev-only now.
    for (const id of ['gemini-3.5-flash', 'gemini-3.1-pro-preview']) {
      expect(body.models.find(m => m.id === id)?.production).toBe(false)
    }
  })
})
