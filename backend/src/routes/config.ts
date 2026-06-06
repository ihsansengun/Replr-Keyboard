import { Hono } from 'hono'
import type { Env } from '../types'

export const configRoute = new Hono<{ Bindings: Env }>()

// Baked-in fallback — must match Constants.shortcutInstallURL in the iOS app.
// Used when the SHORTCUT_INSTALL_URL var is unset.
const DEFAULT_SHORTCUT_INSTALL_URL =
  'https://www.icloud.com/shortcuts/73472454024d4a48b1d2a9108fec4bc8'

// Runtime config the app fetches at launch. Lets us swap the Back Tap shortcut
// link (e.g. if the iCloud link breaks, or we re-share a new version) by changing
// the SHORTCUT_INSTALL_URL var and redeploying — no App Store release required.
configRoute.get('/', (c) =>
  c.json({
    shortcutInstallURL: c.env.SHORTCUT_INSTALL_URL || DEFAULT_SHORTCUT_INSTALL_URL,
  })
)
