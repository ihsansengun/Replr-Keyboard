/** Paywall A/B experiments — which credit packs the app shows, in what order,
 *  with what badge/headline. Changing this file + deploying changes every
 *  user's paywall on next app foreground; no App Store release needed.
 *
 *  To launch a test:
 *    1. Create any new price-point products in App Store Connect (separate
 *       product IDs, e.g. com.ihsan.replr.credits.300.p299 = 300 cr @ £2.99)
 *       and add them to CREDIT_PACKS in services/models.ts (redeem superset).
 *    2. Bump `key` (re-buckets everyone), add variants with weights.
 *    3. Deploy. Read results via the paywall_events query in docs/HANDOFF.md.
 *
 *  Assignment is a pure function of (key, userId) — stable per user for the
 *  experiment's lifetime, no storage, recomputable at impression AND purchase
 *  time so the client can never misreport its bucket. */

export interface PaywallVariant {
  name: string
  weight: number
  /** Ordered App Store product IDs to display. Must all exist in ASC and in CREDIT_PACKS. */
  productIDs: string[]
  /** Product to mark "Most popular". Must be one of productIDs. */
  badgeProductID?: string
  /** Optional headline override for the paywall hero. */
  heroCopy?: string
}

export interface PaywallExperiment {
  key: string
  variants: PaywallVariant[]
}

const BASELINE_PACKS = [
  'com.ihsan.replr.credits.100',
  'com.ihsan.replr.credits.300',
  'com.ihsan.replr.credits.750',
  'com.ihsan.replr.credits.2500',
]

export const ACTIVE_PAYWALL_EXPERIMENT: PaywallExperiment = {
  key: 'paywall-baseline',
  variants: [
    {
      name: 'control',
      weight: 1,
      productIDs: BASELINE_PACKS,
      badgeProductID: 'com.ihsan.replr.credits.300',
    },
  ],
}

/** SHA-256(`key:userId`) → first 4 bytes as uint32 → weighted bucket. */
export async function assignVariant(
  experiment: PaywallExperiment,
  userId: string
): Promise<PaywallVariant> {
  const data = new TextEncoder().encode(`${experiment.key}:${userId}`)
  const digest = await crypto.subtle.digest('SHA-256', data)
  const n = new DataView(digest).getUint32(0)

  const total = experiment.variants.reduce((sum, v) => sum + v.weight, 0)
  let bucket = n % total
  for (const variant of experiment.variants) {
    if (bucket < variant.weight) return variant
    bucket -= variant.weight
  }
  return experiment.variants[experiment.variants.length - 1]
}
