import { describe, it, expect, vi, beforeEach } from 'vitest'
import { parseReplies, parseLlmOutput, generateReplies, buildSystemPrompt } from '../src/services/llm'

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

describe('parseLlmOutput', () => {
  it('extracts CONTACT, SUMMARY, and replies', () => {
    const raw = `CONTACT: Alexis\nSUMMARY: Discussing weekend plans\n1. Sounds fun!\n2. I'm in\n3. Let's do it`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Alexis')
    expect(result.summary).toBe('Discussing weekend plans')
    expect(result.replies).toEqual(["Sounds fun!", "I'm in", "Let's do it"])
  })

  it('returns empty string for contactName when CONTACT line is missing', () => {
    const raw = `SUMMARY: Just chatting\n1. Hey\n2. Sure\n3. Cool`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('')
    expect(result.summary).toBe('Just chatting')
  })

  it('returns "Unknown" as contactName when value is Unknown', () => {
    const raw = `CONTACT: Unknown\nSUMMARY: Chat\n1. Hi`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Unknown')
  })

  it('handles group chat prefix', () => {
    const raw = `CONTACT: Group: Weekend Plans\nSUMMARY: Planning trip\n1. Sounds good`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Group: Weekend Plans')
  })

  it('is case-insensitive for CONTACT: prefix', () => {
    const raw = `contact: Sam\nSUMMARY: Work stuff\n1. Noted`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Sam')
  })

  it('collects multi-line replies (email bodies)', () => {
    const raw = `CONTACT: Nina\nSUMMARY: Email about project\n1. Dear Nina,\n\nThank you for reaching out.\n\nBest regards\n2. Hi Nina,\n\nSounds good to me!\n3. Got it, will follow up.`
    const result = parseLlmOutput(raw)
    expect(result.contactName).toBe('Nina')
    expect(result.replies).toHaveLength(3)
    expect(result.replies[0]).toBe('Dear Nina,\n\nThank you for reaching out.\n\nBest regards')
    expect(result.replies[1]).toBe('Hi Nina,\n\nSounds good to me!')
    expect(result.replies[2]).toBe('Got it, will follow up.')
  })
})

describe('generateReplies', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('calls Claude with correct model and returns parsed LlmResult', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: Dana\nSUMMARY: Work chat\n1. Hey\n2. Sure\n3. Cool' }],
      usage: { input_tokens: 100, output_tokens: 50 },
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude-sonnet-4-6',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toEqual(['Hey', 'Sure', 'Cool'])
    expect(result.summary).toBe('Work chat')
    expect(result.contactName).toBe('Dana')
    expect(anthropicMessagesCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'claude-sonnet-4-6',
      max_tokens: 2048,
    }))
  })

  it('calls GPT-4.1-mini with correct model and returns parsed LlmResult', async () => {
    openaiChatCreate.mockResolvedValue({
      choices: [{ message: { content: 'CONTACT: Pat\nSUMMARY: Weekend plans\n1. Yes\n2. No\n3. Maybe' } }],
      usage: { prompt_tokens: 100, completion_tokens: 50 },
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'gpt-5.4',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toEqual(['Yes', 'No', 'Maybe'])
    expect(result.contactName).toBe('Pat')
    expect(openaiChatCreate).toHaveBeenCalledWith(expect.objectContaining({
      model: 'gpt-5.4',
      max_completion_tokens: 2048,
    }))
  })

  it('returns 5 replies', async () => {
    anthropicMessagesCreate.mockResolvedValue({
      content: [{ type: 'text', text: 'CONTACT: Sam\nSUMMARY: Chat\n1. A\n2. B\n3. C\n4. D\n5. E' }],
      usage: { input_tokens: 100, output_tokens: 50 },
    })

    const result = await generateReplies({
      screenshotBase64: 'abc',
      tone: 'casual',
      model: 'claude-sonnet-4-6',
      anthropicKey: 'key',
      openaiKey: 'key',
    })

    expect(result.replies).toHaveLength(5)
  })
})

describe('buildSystemPrompt', () => {
  it('always includes the Replr identity and the role/tone', () => {
    const sys = buildSystemPrompt('flirty')
    expect(sys).toContain('You are Replr')
    expect(sys).toContain('ROLE: flirty')
  })

  it('includes the ABOUT-THE-USER block when aboutUser is provided', () => {
    const sys = buildSystemPrompt('casual', '27, guy, into climbing and techno')
    expect(sys).toContain('ABOUT THE USER')
    expect(sys).toContain('27, guy, into climbing and techno')
  })

  it('omits the ABOUT block when aboutUser is undefined, empty, or whitespace', () => {
    expect(buildSystemPrompt('casual')).not.toContain('ABOUT THE USER')
    expect(buildSystemPrompt('casual', '')).not.toContain('ABOUT THE USER')
    expect(buildSystemPrompt('casual', '   ')).not.toContain('ABOUT THE USER')
  })

  it('trims the aboutUser text', () => {
    const sys = buildSystemPrompt('casual', '  hi there  ')
    expect(sys).toContain('hi there')
    expect(sys).not.toContain('  hi there  ')
  })

  it('hard-caps aboutUser to protect the system prompt', () => {
    const sys = buildSystemPrompt('casual', 'x'.repeat(500))
    expect(sys).toContain('x'.repeat(300))
    expect(sys).not.toContain('x'.repeat(301))
  })
})
