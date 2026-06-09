import { describe, it, expect, vi } from 'vitest'
import { checkRateLimit } from '../src/services/rateLimit'
import type { KVNamespace } from '@cloudflare/workers-types'

function makeFakeKV(initial?: Record<string, string>): KVNamespace {
  const stored = new Map<string, string>(Object.entries(initial ?? {}))
  return {
    get: vi.fn().mockImplementation(async (key: string) => stored.get(key) ?? null),
    put: vi.fn().mockImplementation(async (key: string, value: string) => { stored.set(key, value) }),
    delete: vi.fn(),
    list: vi.fn(),
    getWithMetadata: vi.fn(),
  } as unknown as KVNamespace
}

const today = new Date().toISOString().split('T')[0]

describe('checkRateLimit', () => {
  it('allows the first request and increments the count', async () => {
    const kv = makeFakeKV()
    const allowed = await checkRateLimit(kv, 'user:abc', 20)
    expect(allowed).toBe(true)
    expect(kv.put).toHaveBeenCalledWith(`rate:user:abc:${today}`, '1', { expirationTtl: 86400 })
  })

  it('blocks when the count reaches the limit', async () => {
    const kv = makeFakeKV({ [`rate:ip:1.2.3.4:${today}`]: '20' })
    const allowed = await checkRateLimit(kv, 'ip:1.2.3.4', 20)
    expect(allowed).toBe(false)
    expect(kv.put).not.toHaveBeenCalled()
  })

  it('allows one below the limit', async () => {
    const kv = makeFakeKV({ [`rate:user:abc:${today}`]: '19' })
    const allowed = await checkRateLimit(kv, 'user:abc', 20)
    expect(allowed).toBe(true)
    expect(kv.put).toHaveBeenCalledWith(expect.anything(), '20', expect.anything())
  })

  it('keeps separate counters per key', async () => {
    const kv = makeFakeKV({ [`rate:ip:1.2.3.4:${today}`]: '20' })
    expect(await checkRateLimit(kv, 'ip:1.2.3.4', 20)).toBe(false)
    expect(await checkRateLimit(kv, 'user:abc', 20)).toBe(true)
  })
})
