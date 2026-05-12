import { Hono } from 'hono'
import { healthRoute } from './routes/health'
import type { Env } from './types'

const app = new Hono<{ Bindings: Env }>()

app.route('/health', healthRoute)

export default app
