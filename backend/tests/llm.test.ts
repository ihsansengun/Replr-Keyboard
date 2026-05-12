import { describe, it, expect, vi, beforeEach } from 'vitest'
import { parseReplies } from '../src/services/llm'

describe('parseReplies', () => {
  it('extracts numbered lines as replies', () => {
    const raw = `1. Hey that's wild\n2. No way haha\n3. That's actually funny`
    expect(parseReplies(raw)).toEqual([
      "Hey that's wild",
      'No way haha',
      "That's actually funny"
    ])
  })

  it('handles extra whitespace', () => {
    const raw = `1.  Hey there \n2.  Sure thing \n3.  Sounds good `
    expect(parseReplies(raw)).toEqual(['Hey there', 'Sure thing', 'Sounds good'])
  })

  it('returns empty array for non-numbered text', () => {
    expect(parseReplies('some random text')).toEqual([])
  })
})
