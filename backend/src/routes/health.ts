import { Hono } from 'hono'
import type { Env } from '../types'

export const healthRoute = new Hono<{ Bindings: Env }>()

healthRoute.get('/', (c) => c.json({ status: 'ok', ts: new Date().toISOString() }))
