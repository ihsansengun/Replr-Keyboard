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

const mockGenerateReplies = vi.mocked(generateReplies)

const fakeEnv = {
  ANTHROPIC_API_KEY: 'test-key',
  OPENAI_API_KEY: 'test-key',
}

const validBody = {
  screenshotBase64: 'aGVsbG8=',
  tone: 'casual',
  model: 'gpt-4.1-mini',
  userId: 'test-user-123',
}

describe('POST /reply', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGenerateReplies.mockResolvedValue({ replies: ['Reply 1', 'Reply 2', 'Reply 3'], summary: 'Test summary', contactName: 'Test Contact', inputTokens: 1000, outputTokens: 100, costUsd: 0.0045 })
  })

  it('returns replies for valid request', async () => {
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validBody),
    }, fakeEnv)
    expect(res.status).toBe(200)
    const json = await res.json() as { replies: string[], contactName: string }
    expect(json.replies).toEqual(['Reply 1', 'Reply 2', 'Reply 3'])
    expect(json.contactName).toBe('Test Contact')
  })

  it('returns 400 when screenshotBase64 is missing', async () => {
    const { screenshotBase64: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 when userId is missing', async () => {
    const { userId: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 when tone is missing', async () => {
    const { tone: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 when model is missing', async () => {
    const { model: _, ...body } = validBody
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 for malformed JSON body', async () => {
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'not valid json{',
    }, fakeEnv)
    expect(res.status).toBe(400)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('Invalid JSON')
  })

  it('returns 400 for invalid model value', async () => {
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validBody, model: 'badmodel' }),
    }, fakeEnv)
    expect(res.status).toBe(400)
    const json = await res.json() as { error: string }
    expect(json.error).toContain('Invalid model')
  })

  it('returns 500 when LLM throws', async () => {
    mockGenerateReplies.mockRejectedValueOnce(new Error('API down'))
    const res = await app.request('/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validBody),
    }, fakeEnv)
    expect(res.status).toBe(500)
  })

  it('accepts all valid model IDs', async () => {
    const models = ['gpt-4.1-mini', 'gpt-5.4-mini', 'gpt-4.1', 'claude-sonnet-4-6']
    for (const model of models) {
      const res = await app.request('/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...validBody, model }),
      }, fakeEnv)
      expect(res.status).toBe(200)
    }
  })
})
