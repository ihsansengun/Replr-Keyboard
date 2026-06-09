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

import { makeTestEnv } from './helpers'

const fakeEnv = makeTestEnv().env

const validScrollBody = {
  screenshots: ['aGVsbG8=', 'd29ybGQ='],
  tone: 'casual',
  model: 'claude-sonnet-4-6',
  userId: 'test-user',
}

describe('POST /reply/scroll', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: '1. Hey\n2. Sure\n3. Cool\n4. Yep\n5. Alright' }],
      usage: { input_tokens: 100, output_tokens: 50 },
    })
  })

  it('returns 5 replies', async () => {
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validScrollBody),
    }, fakeEnv)
    expect(res.status).toBe(200)
    const json = await res.json() as { replies: string[] }
    expect(json.replies).toHaveLength(5)
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

  it('returns 500 when LLM throws', async () => {
    anthropicMessagesCreate.mockRejectedValueOnce(new Error('API down'))
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validScrollBody),
    }, fakeEnv)
    expect(res.status).toBe(500)
  })

  it('returns 400 for too many screenshots', async () => {
    const body = { ...validScrollBody, screenshots: Array(7).fill('aGVsbG8=') }
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 400 for invalid model', async () => {
    const body = { ...validScrollBody, model: 'gpt5' }
    const res = await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('sends all screenshots to LLM as image content', async () => {
    await app.request('/reply/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validScrollBody), // has 2 screenshots
    }, fakeEnv)
    const callArgs = anthropicMessagesCreate.mock.calls[0][0]
    const imageBlocks = callArgs.messages[0].content.filter((b: any) => b.type === 'image')
    expect(imageBlocks).toHaveLength(2)
  })
})
