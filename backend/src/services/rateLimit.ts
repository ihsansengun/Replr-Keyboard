import type { KVNamespace } from '@cloudflare/workers-types'

export async function checkRateLimit(
  kv: KVNamespace,
  userId: string,
  tier: 'free' | 'premium',
  limit: number
): Promise<boolean> {
  if (tier === 'premium') return true

  const today = new Date().toISOString().split('T')[0]
  const key = `rate:${userId}:${today}`
  const current = await kv.get(key)
  const count = parseInt(current ?? '0', 10)

  if (count >= limit) return false

  await kv.put(key, String(count + 1), { expirationTtl: 86400 })
  return true
}
