import { describe, it, expect, vi, beforeEach } from 'vitest'

// vi.mock is hoisted to the top by Vitest. Factory functions must NOT
// reference variables declared in the outer scope (they aren't initialised yet).
// We use vi.fn() inline here and retrieve the mocks via vi.mocked() below.

vi.mock('../src/services/llm', () => ({
  generateReplies: vi.fn(),
}))

vi.mock('../src/services/rateLimit', () => ({
  checkRateLimit: vi.fn(),
}))

// Import app and the mocked modules AFTER vi.mock calls.
import { app } from '../src/index'
import { generateReplies } from '../src/services/llm'
import { checkRateLimit } from '../src/services/rateLimit'

const mockGenerateReplies = vi.mocked(generateReplies)
const mockCheckRateLimit = vi.mocked(checkRateLimit)

const validBody = {
  screenshotBase64: 'aGVsbG8=',
  tone: 'casual',
  model: 'claude',
  userId: 'test-user-123',
}

describe('POST /reply', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGenerateReplies.mockResolvedValue(['Reply 1', 'Reply 2', 'Reply 3'])
    mockCheckRateLimit.mockResolvedValue(true)
  })

  it('returns replies for valid request', async () => {
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validBody),
    })
    expect(res.status).toBe(200)
    const json = await res.json() as { replies: string[] }
    expect(json.replies).toEqual(['Reply 1', 'Reply 2', 'Reply 3'])
  })

  it('returns 400 when screenshotBase64 is missing', async () => {
    const { screenshotBase64: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    expect(res.status).toBe(400)
  })

  it('returns 400 when userId is missing', async () => {
    const { userId: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    expect(res.status).toBe(400)
  })

  it('returns 400 when tone is missing', async () => {
    const { tone: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    expect(res.status).toBe(400)
  })

  it('returns 400 when model is missing', async () => {
    const { model: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    expect(res.status).toBe(400)
  })

  it('returns 429 when rate limit exceeded', async () => {
    mockCheckRateLimit.mockResolvedValueOnce(false)
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validBody),
    })
    expect(res.status).toBe(429)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('Daily limit')
  })

  it('returns 500 when LLM throws', async () => {
    mockGenerateReplies.mockRejectedValueOnce(new Error('API down'))
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validBody),
    })
    expect(res.status).toBe(500)
  })

  it('sets tier to premium when transactionId is provided', async () => {
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validBody, transactionId: 'txn-abc' }),
    })
    expect(res.status).toBe(200)
    // c.env bindings are undefined in test; FREE_DAILY_LIMIT falls back to '20'
    expect(mockCheckRateLimit).toHaveBeenCalledWith(
      undefined,
      'test-user-123',
      'premium',
      20
    )
  })
})
