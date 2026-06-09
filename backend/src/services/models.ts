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
  { id: 'gemini-3.5-flash',       label: '3.5 Flash',    creditCost: 4,  production: true  },
  { id: 'gemini-3.1-pro-preview', label: 'Pro High',     creditCost: 6,  production: true  },
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

/** StoreKit consumable product IDs → credits granted. Must match the packs in
 *  the iOS app (CreditsManager.productIDs). */
export const CREDIT_PACKS: Record<string, number> = {
  'com.ihsan.replr.credits.100': 100,
  'com.ihsan.replr.credits.300': 300,
  'com.ihsan.replr.credits.750': 750,
  'com.ihsan.replr.credits.2500': 2500,
}
