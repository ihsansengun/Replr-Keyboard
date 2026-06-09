import { describe, it, expect } from 'vitest'
import { app } from '../src/index'

describe('GET /config', () => {
  it('returns the configured shortcut install URL', async () => {
    const res = await app.request('/config', {}, {
      SHORTCUT_INSTALL_URL: 'https://www.icloud.com/shortcuts/abc123',
    })
    expect(res.status).toBe(200)
    const body = await res.json() as { shortcutInstallURL: string }
    expect(body.shortcutInstallURL).toBe('https://www.icloud.com/shortcuts/abc123')
  })

  it('falls back to the baked-in default when the var is unset', async () => {
    const res = await app.request('/config', {}, {})
    expect(res.status).toBe(200)
    const body = await res.json() as { shortcutInstallURL: string }
    expect(body.shortcutInstallURL).toContain('icloud.com/shortcuts/')
  })

  it('serves the model catalog with a default model', async () => {
    const res = await app.request('/config', {}, {})
    expect(res.status).toBe(200)
    const body = await res.json() as {
      defaultModel: string
      models: Array<{ id: string; label: string; creditCost: number; production: boolean }>
    }
    expect(body.defaultModel).toBe('gemini-3.5-flash')
    expect(body.models).toHaveLength(15)
    for (const m of body.models) {
      expect(typeof m.id).toBe('string')
      expect(typeof m.label).toBe('string')
      expect(m.creditCost).toBeGreaterThan(0)
      expect(typeof m.production).toBe('boolean')
    }
    const def = body.models.find(m => m.id === body.defaultModel)
    expect(def?.production).toBe(true)
  })
})
