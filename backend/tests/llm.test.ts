import { describe, it, expect, vi, beforeEach } from 'vitest'
import { parseReplies, generateReplies } from '../src/services/llm'

// Module-level mocks (hoisted by Vitest).
// The mock factories must use regular functions (not arrow functions) so that
// `new Anthropic()` / `new OpenAI()` work correctly — arrow functions cannot
// be used as constructors.

const anthropicMessagesCreate = vi.fn()
const openaiChatCreate = vi.fn()

vi.mock('@anthropic-ai/sdk', () => ({
  default: function MockAnthropic() {
    return { messages: { create: anthropicMessagesCreate } }
  },
}))

vi.mock('openai', () => ({
  default: function MockOpenAI() {
    return { chat: { completions: { create: openaiChatCreate } } }
  },
}))

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

  it('handles indented numbered lines', () => {
    const raw = `  1. Got it\n  2. Makes sense\n  3. For sure`
    expect(parseReplies(raw)).toEqual(['Got it', 'Makes sense', 'For sure'])
  })
})

describe('generateReplies', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('calls Claude with correct model and returns parsed replies', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: '1. Hey\n2. Sure\n3. Cool' }],
    })

    const replies = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude',
      tier: 'free',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(replies).toEqual(['Hey', 'Sure', 'Cool'])
    expect(anthropicMessagesCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
    }))
  })

  it('calls GPT-4o with correct model and returns parsed replies', async () => {
    openaiChatCreate.mockResolvedValue({
      choices: [{ message: { content: '1. Yes\n2. No\n3. Maybe' } }],
    })

    const replies = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'gpt4o',
      tier: 'free',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(replies).toEqual(['Yes', 'No', 'Maybe'])
    expect(openaiChatCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'gpt-4o',
      max_tokens: 1024,
    }))
  })

  it('returns 5 replies for premium tier', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: '1. A\n2. B\n3. C\n4. D\n5. E' }],
    })

    const replies = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude',
      tier: 'premium',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(replies).toHaveLength(5)
  })
})
