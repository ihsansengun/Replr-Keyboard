import { Hono } from 'hono'
import type { Env } from '../types'
import { MODEL_CATALOG, DEFAULT_MODEL } from '../services/models'

export const configRoute = new Hono<{ Bindings: Env }>()

// Baked-in fallback — must match Constants.shortcutInstallURL in the iOS app.
// Used when the SHORTCUT_INSTALL_URL var is unset.
const DEFAULT_SHORTCUT_INSTALL_URL =
  'https://www.icloud.com/shortcuts/73472454024d4a48b1d2a9108fec4bc8'

// Runtime config the app fetches at launch. Lets us swap the Back Tap shortcut
// link and the model catalog (costs/labels/availability) by redeploying — no
// App Store release required. The app caches `models` in the App Group and
// falls back to its baked-in table when this hasn't been fetched yet.
configRoute.get('/', (c) =>
  c.json({
    shortcutInstallURL: c.env.SHORTCUT_INSTALL_URL || DEFAULT_SHORTCUT_INSTALL_URL,
    defaultModel: DEFAULT_MODEL,
    models: MODEL_CATALOG,
  })
)
