import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('../src/services/auth', () => ({
  validateAppleToken: vi.fn(),
}))

import { app } from '../src/index'
import { validateAppleToken } from '../src/services/auth'
const mockValidate = vi.mocked(validateAppleToken)

// Minimal D1 stub that simulates a new user (SELECT returns null, INSERT succeeds).
const mockDB = {
  prepare: (_sql: string) => ({
    bind: (..._args: unknown[]) => ({
      first: async () => null,
      run: async () => ({ success: true }),
    }),
  }),
}

const fakeEnv = {
  ANTHROPIC_API_KEY: 'test',
  OPENAI_API_KEY: 'test',
  RATE_LIMIT_KV: { get: async () => null, put: async () => {} },
  DB: mockDB,
  FREE_DAILY_LIMIT: '200',
}

describe('POST /auth/apple', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockValidate.mockResolvedValue({
      sub: 'apple-user-123',
      email: 'user@example.com',
      iss: 'https://appleid.apple.com',
      aud: 'com.ihsan.replr',
      exp: 9999999999,
      iat: 1000000000,
    })
  })

  it('returns 400 when identityToken is missing', async () => {
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 401 when Apple token is invalid', async () => {
    mockValidate.mockRejectedValue(new Error('invalid'))
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken: 'bad-token' }),
    }, fakeEnv)
    expect(res.status).toBe(401)
  })

  it('returns 200 with a 64-char hex session token for a valid Apple token', async () => {
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken: 'valid-token' }),
    }, fakeEnv)
    expect(res.status).toBe(200)
    const body = await res.json() as { token: string; expiresAt: number }
    expect(typeof body.token).toBe('string')
    expect(body.token).toHaveLength(64)
    expect(typeof body.expiresAt).toBe('number')
  })
})
