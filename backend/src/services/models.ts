import type { Model } from '../types'

export interface CatalogModel {
  id: Model
  label: string        // short UI label (matches the app's selectedModelShortLabel)
  creditCost: number   // credits charged per generation
  production: boolean  // shown to non-dev users in the app
}

/** Single source of truth for which models exist, what they cost in credits,
 *  and what the app should call them. Served to the app via GET /config so
 *  costs/labels/additions don't require an App Store release.
 *  (Provider API pricing lives separately in llm.ts PRICING.) */
export const MODEL_CATALOG: CatalogModel[] = [
  { id: 'gemini-3.5-flash',       label: '3.5 Flash',    creditCost: 4,  production: false },
  { id: 'gemini-3.1-pro-preview', label: 'Pro High',     creditCost: 6,  production: false },
  { id: 'gemini-3.1-pro-low',     label: 'Pro Low',      creditCost: 6,  production: false },
  { id: 'gemini-3-flash-preview', label: 'Gemini Flash', creditCost: 3,  production: false },
  { id: 'gemini-3.1-flash-lite',  label: 'Flash Lite',   creditCost: 2,  production: false },
  { id: 'gemini-2.5-pro',         label: '2.5 Pro',      creditCost: 4,  production: false },
  { id: 'claude-sonnet-4-6',      label: 'Sonnet 4.6',   creditCost: 8,  production: false },
  { id: 'claude-opus-4-6',        label: 'Opus 4.6',     creditCost: 15, production: false },
  { id: 'claude-opus-4-7',        label: 'Opus 4.7',     creditCost: 15, production: false },
  { id: 'claude-haiku-4-5',       label: 'Haiku 4.5',    creditCost: 3,  production: false },
  { id: 'gpt-5.4',                label: 'GPT-5.4',      creditCost: 7,  production: false },
  { id: 'gpt-5.4-mini',           label: '5.4 Mini',     creditCost: 2,  production: false },
  { id: 'gpt-5.5',                label: 'GPT-5.5',      creditCost: 15, production: false },
  { id: 'grok-4',                 label: 'Grok 4',       creditCost: 7,  production: false },
  { id: 'grok-4.3',               label: 'Grok 4.3',     creditCost: 2,  production: false },
]

export const DEFAULT_MODEL: Model = 'gemini-3.5-flash'

export const VALID_MODELS: Model[] = MODEL_CATALOG.map(m => m.id)

/** Fallback 7 matches the app's AppGroupService.creditsRequired default. */
export function creditCostFor(model: string): number {
  return MODEL_CATALOG.find(m => m.id === model)?.creditCost ?? 7
}

// ── Quality tiers ────────────────────────────────────────────────────────────

/** User-facing quality tiers — the stable ids the app sends as `model`. The
 *  server resolves which vendor model a tier means TODAY, so repointing a tier
 *  (Gemini → Claude → whatever wins) is a backend-only deploy: no app release,
 *  and users never see vendor churn. `creditCost` is the tier's PRICE and is
 *  deliberately independent of the underlying model's catalog cost — swapping
 *  vendors must never silently change what users pay. */
export interface Tier {
  id: string
  label: string
  creditCost: number
  model: Model
}

export const TIERS: Tier[] = [
  { id: 'balanced', label: 'Balanced', creditCost: 4, model: 'gemini-3.5-flash' },
  { id: 'max',      label: 'Max',      creditCost: 6, model: 'gemini-3.1-pro-preview' },
]

export function resolveTier(id: string | undefined): Tier | undefined {
  return TIERS.find(t => t.id === id)
}

/** Everything the app may send as `model`: tiers (user-facing) + raw vendor
 *  ids (dev mode). Used for the 400 error message. */
export const REQUESTABLE_MODELS: string[] = [...TIERS.map(t => t.id), ...VALID_MODELS]

/** What new app builds should default to. (DEFAULT_MODEL above stays the raw
 *  vendor default for internal use.) */
export const DEFAULT_REQUEST_MODEL = 'balanced'

/** Catalog as served by /config: tiers first (production = shown to users),
 *  then the raw vendor models (dev-only). Same field shape as CatalogModel so
 *  existing app builds keep decoding and can still look up raw-id costs. */
export interface ServedModel {
  id: string
  label: string
  creditCost: number
  production: boolean
}

export function servedCatalog(): ServedModel[] {
  return [
    ...TIERS.map(t => ({ id: t.id, label: t.label, creditCost: t.creditCost, production: true })),
    ...MODEL_CATALOG,
  ]
}

/** StoreKit consumable product IDs → credits granted. Must match the packs in
 *  the iOS app (CreditsManager.productIDs). */
export const CREDIT_PACKS: Record<string, number> = {
  'com.ihsan.replr.credits.100': 100,
  'com.ihsan.replr.credits.300': 300,
  'com.ihsan.replr.credits.750': 750,
  'com.ihsan.replr.credits.2500': 2500,
}
