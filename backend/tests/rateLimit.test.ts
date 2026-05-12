import { describe, it, expect, vi } from 'vitest'
import { checkRateLimit } from '../src/services/rateLimit'
import type { KVNamespace } from '@cloudflare/workers-types'

function makeFakeKV(initial?: string): KVNamespace {
  let stored: string | null = initial ?? null
  return {
    get: vi.fn().mockImplementation(async () => stored),
    put: vi.fn().mockImplementation(async (_key: string, value: string) => { stored = value }),
    delete: vi.fn(),
    list: vi.fn(),
    getWithMetadata: vi.fn(),
  } as unknown as KVNamespace
}

describe('checkRateLimit', () => {
  it('allows premium tier without touching KV', async () => {
    const kv = makeFakeKV()
    const allowed = await checkRateLimit(kv, 'user1', 'premium', 20)
    expect(allowed).toBe(true)
    expect(kv.get).not.toHaveBeenCalled()
  })

  it('allows free tier on first request and increments count', async () => {
    const kv = makeFakeKV()
    const allowed = await checkRateLimit(kv, 'user1', 'free', 20)
    expect(allowed).toBe(true)
    expect(kv.put).toHaveBeenCalledWith(expect.stringContaining('rate:user1:'), '1', { expirationTtl: 86400 })
  })

  it('blocks free tier when count reaches limit', async () => {
    const kv = makeFakeKV('20')
    const allowed = await checkRateLimit(kv, 'user1', 'free', 20)
    expect(allowed).toBe(false)
    expect(kv.put).not.toHaveBeenCalled()
  })

  it('allows free tier one below the limit', async () => {
    const kv = makeFakeKV('19')
    const allowed = await checkRateLimit(kv, 'user1', 'free', 20)
    expect(allowed).toBe(true)
    expect(kv.put).toHaveBeenCalledWith(expect.anything(), '20', expect.anything())
  })
})
