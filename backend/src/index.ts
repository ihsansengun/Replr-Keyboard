import { Hono } from 'hono'
import { healthRoute } from './routes/health'
import { replyRoute } from './routes/reply'
import type { Env } from './types'

export const app = new Hono<{ Bindings: Env }>()

app.route('/health', healthRoute)
app.route('/reply', replyRoute)

export default app
