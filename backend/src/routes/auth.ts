import { Hono } from 'hono'
import type { Env } from '../types'
import { validateAppleToken } from '../services/auth'

export const authRoute = new Hono<{ Bindings: Env }>()

const APPLE_AUDIENCE = 'Theory-of-Web.Replr'
const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60  // 30 days

authRoute.post('/apple', async (c) => {
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { identityToken, email, name } = body as {
    identityToken?: string
    email?: string
    name?: string
  }

  if (!identityToken || typeof identityToken !== 'string') {
    return c.json({ error: 'Missing identityToken' }, 400)
  }

  let claims: { sub: string; email?: string }
  try {
    claims = await validateAppleToken(identityToken, APPLE_AUDIENCE)
  } catch (err) {
    console.error('Apple token validation failed:', err)
    return c.json({ error: 'Invalid Apple identity token' }, 401)
  }

  const now = Math.floor(Date.now() / 1000)

  // Upsert user — Apple only sends email on first sign-in; preserve it thereafter.
  const existing = await c.env.DB
    .prepare('SELECT id, email FROM users WHERE apple_id = ?')
    .bind(claims.sub)
    .first<{ id: string; email: string | null }>()

  let userID: string
  if (existing) {
    userID = existing.id
    // Apple sent an email this time but we didn't have one — store it now.
    const incomingEmail = email ?? claims.email ?? null
    if (incomingEmail && !existing.email) {
      await c.env.DB
        .prepare('UPDATE users SET email = ? WHERE id = ?')
        .bind(incomingEmail, userID)
        .run()
    }
  } else {
    userID = crypto.randomUUID()
    const storedEmail = email ?? claims.email ?? null
    const storedName = (name && name.trim()) ? name.trim() : null
    await c.env.DB
      .prepare('INSERT INTO users (id, apple_id, email, name, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(userID, claims.sub, storedEmail, storedName, now)
      .run()
  }

  // Generate a 64-char hex session token (32 cryptographically random bytes).
  const tokenBytes = new Uint8Array(32)
  crypto.getRandomValues(tokenBytes)
  const token = Array.from(tokenBytes).map(b => b.toString(16).padStart(2, '0')).join('')
  const expiresAt = now + SESSION_TTL_SECONDS

  await c.env.DB
    .prepare('INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(token, userID, expiresAt, now)
    .run()

  return c.json({ token, expiresAt })
})
