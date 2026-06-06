import { Hono } from 'hono'
import { healthRoute } from './routes/health'
import { replyRoute } from './routes/reply'
import { configRoute } from './routes/config'
import type { Env } from './types'

export const app = new Hono<{ Bindings: Env }>()

app.route('/health', healthRoute)
app.route('/reply', replyRoute)
app.route('/config', configRoute)

export default app
