import { describe, it, expect } from 'vitest'
import { assignVariant, ACTIVE_PAYWALL_EXPERIMENT, type PaywallExperiment } from '../src/services/paywall'

const TEST_EXPERIMENT: PaywallExperiment = {
  key: 'test-exp-1',
  variants: [
    { name: 'control', weight: 1, productIDs: ['a', 'b'] },
    { name: 'cheaper', weight: 1, productIDs: ['a2', 'b2'], badgeProductID: 'a2' },
  ],
}

describe('assignVariant', () => {
  it('is deterministic for the same user and experiment key', async () => {
    const first = await assignVariant(TEST_EXPERIMENT, 'user-123')
    for (let i = 0; i < 5; i++) {
      expect((await assignVariant(TEST_EXPERIMENT, 'user-123')).name).toBe(first.name)
    }
  })

  it('distributes users roughly according to weights', async () => {
    const counts: Record<string, number> = {}
    for (let i = 0; i < 1000; i++) {
      const v = await assignVariant(TEST_EXPERIMENT, `uid-${i}`)
      counts[v.name] = (counts[v.name] ?? 0) + 1
    }
    // 50/50 split ±10 points on 1000 samples
    expect(counts.control).toBeGreaterThan(400)
    expect(counts.control).toBeLessThan(600)
    expect(counts.cheaper).toBeGreaterThan(400)
    expect(counts.cheaper).toBeLessThan(600)
  })

  it('respects uneven weights', async () => {
    const exp: PaywallExperiment = {
      key: 'test-exp-2',
      variants: [
        { name: 'big', weight: 9, productIDs: ['a'] },
        { name: 'small', weight: 1, productIDs: ['b'] },
      ],
    }
    let small = 0
    for (let i = 0; i < 1000; i++) {
      if ((await assignVariant(exp, `uid-${i}`)).name === 'small') small++
    }
    expect(small).toBeGreaterThan(50)
    expect(small).toBeLessThan(180)
  })

  it('reshuffles when the experiment key changes', async () => {
    const moved: string[] = []
    for (let i = 0; i < 50; i++) {
      const a = await assignVariant({ ...TEST_EXPERIMENT, key: 'k1' }, `uid-${i}`)
      const b = await assignVariant({ ...TEST_EXPERIMENT, key: 'k2' }, `uid-${i}`)
      if (a.name !== b.name) moved.push(`uid-${i}`)
    }
    expect(moved.length).toBeGreaterThan(5)   // a new key re-buckets a meaningful share
  })

  it('ships a baseline experiment whose variants all reference real packs', async () => {
    expect(ACTIVE_PAYWALL_EXPERIMENT.variants.length).toBeGreaterThan(0)
    for (const v of ACTIVE_PAYWALL_EXPERIMENT.variants) {
      expect(v.productIDs.length).toBeGreaterThan(0)
      if (v.badgeProductID) expect(v.productIDs).toContain(v.badgeProductID)
    }
  })
})
