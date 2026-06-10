import { Hono } from 'hono'
import { healthRoute } from './routes/health'
import { replyRoute } from './routes/reply'
import { configRoute } from './routes/config'
import { authRoute } from './routes/auth'
import { creditsRoute } from './routes/credits'
import { paywallRoute } from './routes/paywall'
import type { Env } from './types'

export const app = new Hono<{ Bindings: Env }>()

app.route('/health', healthRoute)
app.route('/auth', authRoute)
app.route('/reply', replyRoute)
app.route('/config', configRoute)
app.route('/credits', creditsRoute)
app.route('/paywall', paywallRoute)

export default app
