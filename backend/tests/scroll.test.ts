import { describe, it, expect, vi, beforeEach } from 'vitest'
import { app } from '../src/index'

// Reuse the same mock pattern as reply.test.ts
const anthropicMessagesCreate = vi.fn()
const openaiChatCreate = vi.fn()

vi.mock('@anthropic-ai/sdk', () => ({
  default: function() {
    return { messages: { create: anthropicMessagesCreate } }
  }
}))

vi.mock('openai', () => ({
  default: function() {
    return { chat: { completions: { create: openaiChatCreate } } }
  }
}))

const fakeEnv = {
  RATE_LIMIT_KV: { get: vi.fn().mockResolvedValue(null), put: vi.fn() },
  FREE_DAILY_LIMIT: '20',
  ANTHROPIC_API_KEY: 'test-key',
  OPENAI_API_KEY: 'test-key',
}

const validScrollBody = {
  screenshots: ['aGVsbG8=', 'd29ybGQ='],
  tone: 'casual',
  model: 'claude',
  userId: 'test-user',
  transactionId: 'tx-123', // must be premium
}

describe('POST /reply/scroll', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: '1. Hey\n2. Sure\n3. Cool\n4. Yep\n5. Alright' }]
    })
  })

  it('returns 5 replies for premium user', async () => {
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validScrollBody),
    }, fakeEnv)
    expect(res.status).toBe(200)
    const json = await res.json() as { replies: string[] }
    expect(json.replies).toHaveLength(5)
  })

  it('returns 403 for non-premium (no transactionId)', async () => {
    const { transactionId: _, ...body } = validScrollBody
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(403)
  })

  it('returns 400 when screenshots array is empty', async () => {
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validScrollBody, screenshots: [] }),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 when screenshots is missing', async () => {
    const { screenshots: _, ...body } = validScrollBody
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })
})
