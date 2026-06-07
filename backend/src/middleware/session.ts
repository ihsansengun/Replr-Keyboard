import type { MiddlewareHandler } from 'hono'
import type { Env } from '../types'

export const SESSION_USER_ID_KEY = 'authenticatedUserID'

export type SessionVariables = {
  [SESSION_USER_ID_KEY]: string | undefined
}

/**
 * Reads `Authorization: Bearer <token>`, validates against the sessions table,
 * and sets SESSION_USER_ID_KEY in the Hono context.
 *
 * Non-blocking: missing or invalid tokens are silently ignored so existing
 * anonymous clients keep working.
 */
export const sessionMiddleware: MiddlewareHandler<{
  Bindings: Env
  Variables: SessionVariables
}> = async (c, next) => {
  const authorization = c.req.header('Authorization')
  if (authorization?.startsWith('Bearer ')) {
    const token = authorization.slice(7).trim()
    if (token.length === 64) {  // our tokens are always 64 hex chars
      const now = Math.floor(Date.now() / 1000)
      try {
        const session = await c.env.DB
          .prepare('SELECT user_id FROM sessions WHERE token = ? AND expires_at > ?')
          .bind(token, now)
          .first<{ user_id: string }>()
        if (session) {
          c.set(SESSION_USER_ID_KEY, session.user_id)
        }
      } catch (err) {
        console.error('[sessionMiddleware] D1 error:', err)
      }
    }
  }
  await next()
}
