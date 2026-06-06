import { describe, it, expect } from 'vitest'
import { toneSpecFor, TONE_LIBRARY } from '../src/services/tones'

describe('toneSpecFor', () => {
  it('returns the library spec for a known tone (with examples + temperature)', () => {
    const r = toneSpecFor('Joker', 'the sent instruction')
    expect(r.temperature).toBeGreaterThan(0.9)
    expect(r.examples.length).toBeGreaterThan(0)
    expect(r.baseOnly).toBe(false)
    expect(r.voice).toBe('the sent instruction') // no voiceOverride this pass → uses the sent instruction
  })

  it('marks Natural as base-only with no overlay voice', () => {
    const r = toneSpecFor('Natural', 'whatever')
    expect(r.baseOnly).toBe(true)
    expect(r.voice).toBe('')
    expect(r.examples).toEqual([])
  })

  it('falls back for an unknown/custom tone: sent instruction, no examples, default temperature', () => {
    const r = toneSpecFor('My Custom Tone', 'be a pirate')
    expect(r.voice).toBe('be a pirate')
    expect(r.examples).toEqual([])
    expect(r.baseOnly).toBe(false)
    expect(r.temperature).toBeCloseTo(0.85)
  })

  it('falls back when toneName is undefined (older clients)', () => {
    const r = toneSpecFor(undefined, 'be warm')
    expect(r.voice).toBe('be warm')
    expect(r.temperature).toBeCloseTo(0.85)
  })

  it('gives structured tones a low temperature and bold tones a high one', () => {
    expect(toneSpecFor('Direct', 'x').temperature).toBeLessThan(0.7)
    expect(toneSpecFor('Seductive', 'x').temperature).toBeGreaterThan(0.9)
  })

  it('has a library entry for every shipped preset name (incl. new + compat alias)', () => {
    const names = [
      // Default visible tones
      'Natural','Friendly','Casual','Playful','Witty','Joker','Flirty','Seductive',
      'Empathetic','Confident','Direct',
      // Hidden-by-default tones
      'Sarcastic','Passive Aggressive','Gen Z','Enthusiastic','Concise','Professional','Formal',
      // Backward-compat alias (Dating → Flirty rename)
      'Dating',
    ]
    for (const n of names) expect(TONE_LIBRARY[n], n).toBeDefined()
  })

  it('Confident has a low-moderate temperature (self-assured brevity)', () => {
    expect(toneSpecFor('Confident', 'x').temperature).toBeLessThan(0.85)
  })

  it('Playful has examples and a creative temperature', () => {
    const r = toneSpecFor('Playful', 'be fun')
    expect(r.examples.length).toBeGreaterThan(0)
    expect(r.temperature).toBeGreaterThanOrEqual(0.85)
  })

  it('Flirty and Dating resolve to the same temperature (compat alias)', () => {
    expect(toneSpecFor('Flirty', 'x').temperature).toBe(toneSpecFor('Dating', 'x').temperature)
  })
})
