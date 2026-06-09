import type { KVNamespace } from '@cloudflare/workers-types'

/** Daily fixed-window limiter keyed by an arbitrary string (`user:<id>` or `ip:<addr>`).
 *  KV read-then-write is not atomic — concurrent requests can slightly exceed the
 *  limit. Acceptable for an abuse backstop; atomic would require a Durable Object. */
export async function checkRateLimit(
  kv: KVNamespace,
  key: string,
  limit: number
): Promise<boolean> {
  const today = new Date().toISOString().split('T')[0]
  const kvKey = `rate:${key}:${today}`
  const current = await kv.get(kvKey)
  const count = parseInt(current ?? '0', 10)

  if (count >= limit) return false

  await kv.put(kvKey, String(count + 1), { expirationTtl: 86400 })
  return true
}
