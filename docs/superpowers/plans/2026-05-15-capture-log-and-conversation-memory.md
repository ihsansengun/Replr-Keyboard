# Capture Log & Conversation Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After each generation, save a `CaptureSession` (thumbnail + context + replies + LLM summary) visible in the companion app, and automatically feed recent session summaries back into the next generation as accumulated conversation context.

**Architecture:** `GenerateReplyIntent` builds a `CaptureSession` after each successful API call, stores it in App Group UserDefaults, and passes summaries from recent sessions (last 4 hours) as `previousContext` to the backend. The backend prompts the LLM to output a `SUMMARY:` line alongside replies; that summary is stored per session. The companion app gains a "Captures" tab reading sessions from App Group. The keyboard records which reply the user selected by updating the most recent session.

**Tech Stack:** Swift/SwiftUI (iOS), TypeScript (Cloudflare Workers/Hono), App Group UserDefaults for IPC, `@anthropic-ai/sdk`, `openai`.

---

## File Structure

**New files:**
- `Shared/Models/CaptureSession.swift` — `CaptureSession` Codable model
- `Replr/Replr/Features/Captures/CaptureLogView.swift` — companion app captures tab

**Modified files:**
- `Shared/Constants.swift` — add `captureSessionsKey`
- `Shared/AppGroupService.swift` — add session CRUD + `activeSessionSummaries()`
- `Shared/Services/ReplyService.swift` — add `previousContext` to request, `summary` to response, return `ReplyResult`
- `Shared/GenerateReplyIntent.swift` — build+save session, pass previous context, include thumbnail
- `ReplrKeyboard/KeyboardViewController.swift` — mark selected reply on most recent session
- `Replr/Replr/App/ReplrApp.swift` — add Captures tab
- `backend/src/types/index.ts` — `previousContext` in request, `summary` in response
- `backend/src/services/llm.ts` — update prompts + parsing to extract SUMMARY line
- `backend/src/routes/reply.ts` — pass `previousContext`, return `summary`

> **Note:** `Shared/ReplyService.swift` and `Shared/Services/ReplyService.swift` appear to be duplicates. The canonical file is `Shared/Services/ReplyService.swift`. If both are in the Xcode target, delete `Shared/ReplyService.swift` from the target (do not delete the file until confirmed safe).

---

### Task 1: `CaptureSession` model + App Group infrastructure

**Files:**
- Create: `Shared/Models/CaptureSession.swift`
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Create `CaptureSession` model**

Create `/Users/WORK2/Desktop/Replr/Shared/Models/CaptureSession.swift`:

```swift
import Foundation

struct CaptureSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let thumbnailData: Data?      // ~30 KB JPEG of the screenshot
    let contextHint: String?      // text from "Use as context" if provided
    let generatedReplies: [String]
    var selectedReply: String?    // set when user taps Use on a reply card
    var llmSummary: String?       // one-line summary extracted by the LLM
}
```

- [ ] **Step 2: Add `captureSessionsKey` to Constants**

In `/Users/WORK2/Desktop/Replr/Shared/Constants.swift`, add after `cachedRepliesKey`:

```swift
static let captureSessionsKey     = "capture_sessions"
```

- [ ] **Step 3: Add session methods to AppGroupService**

In `/Users/WORK2/Desktop/Replr/Shared/AppGroupService.swift`, add a new `MARK: - Capture sessions` section after the `isGenerating` block:

```swift
// MARK: - Capture sessions

private static let maxSessions = 50
private static let conversationWindowSeconds: TimeInterval = 4 * 60 * 60  // 4 hours

func saveCaptureSessions(_ sessions: [CaptureSession]) {
    guard let data = try? JSONEncoder().encode(sessions) else { return }
    defaults.set(data, forKey: Constants.captureSessionsKey)
    defaults.synchronize()
}

func loadCaptureSessions() -> [CaptureSession] {
    defaults.synchronize()
    guard let data = defaults.data(forKey: Constants.captureSessionsKey),
          let sessions = try? JSONDecoder().decode([CaptureSession].self, from: data)
    else { return [] }
    return sessions
}

func appendCaptureSession(_ session: CaptureSession) {
    var sessions = loadCaptureSessions()
    sessions.append(session)
    if sessions.count > Self.maxSessions {
        sessions.removeFirst(sessions.count - Self.maxSessions)
    }
    saveCaptureSessions(sessions)
}

func markLastSessionReplySelected(_ reply: String) {
    var sessions = loadCaptureSessions()
    guard !sessions.isEmpty else { return }
    sessions[sessions.count - 1].selectedReply = reply
    saveCaptureSessions(sessions)
}

/// Summaries from sessions within the last 4 hours, oldest first.
func activeSessionSummaries() -> [String] {
    let cutoff = Date().addingTimeInterval(-Self.conversationWindowSeconds)
    return loadCaptureSessions()
        .filter { $0.timestamp > cutoff }
        .compactMap { $0.llmSummary }
}

func clearCaptureSessions() {
    defaults.removeObject(forKey: Constants.captureSessionsKey)
    defaults.synchronize()
}
```

- [ ] **Step 4: Build the Shared target and confirm it compiles**

Open the Replr Xcode project at `/Users/WORK2/Desktop/Replr/Replr/Replr.xcodeproj`. Select any target that includes Shared files (e.g. the main Replr target) and press ⌘B. Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add Shared/Models/CaptureSession.swift Shared/Constants.swift Shared/AppGroupService.swift
git commit -m "feat: add CaptureSession model and App Group session infrastructure"
```

---

### Task 2: Backend — extract LLM summary, accept previous context

**Files:**
- Modify: `backend/src/types/index.ts`
- Modify: `backend/src/services/llm.ts`
- Modify: `backend/src/routes/reply.ts`

- [ ] **Step 1: Update types**

Replace the contents of `/Users/WORK2/Desktop/Replr/backend/src/types/index.ts`:

```typescript
export type Model = 'claude' | 'gpt4o'
export type Tier = 'free' | 'premium'

export interface Env {
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  FREE_DAILY_LIMIT: string
  RATE_LIMIT_KV: KVNamespace
}

export interface ReplyRequest {
  screenshotBase64?: string
  emailText?: string
  tone: string
  summary?: string
  previousContext?: string   // accumulated conversation summaries from prior sessions
  model: Model
  userId: string
  transactionId?: string
}

export interface ReplyResponse {
  replies: string[]
  summary: string            // one-line LLM-extracted summary of this session
}
```

- [ ] **Step 2: Update `llm.ts` — prompt asks LLM for SUMMARY line, parser extracts it**

Replace `/Users/WORK2/Desktop/Replr/backend/src/services/llm.ts`:

```typescript
import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import type { Model, Tier } from '../types'

const IDENTITY = `You are Replr. You generate human-like replies to text conversations.

Rules:
- Never sound like AI
- No filler openers: "Certainly", "Of course", "Great question", "I'd be happy to"
- Never ask more than one question per reply
- Each option must be distinct in angle or energy
- Match the reply length rhythm of the conversation`

const TONE_PROMPTS: Record<string, string> = {
  casual:       'Relaxed, warm, natural. Contractions always. Match their energy exactly.',
  friendly:     'Warm, positive, and genuine. Light energy without being over-the-top.',
  dating:       'Confident and genuine. Light wit when it fits. Never desperate, never try-hard.',
  professional: 'Clear, competent, respectful. Formal but not stiff.',
  formal:       'Polished and structured. Appropriate for official or high-stakes messages.',
  email:        'Structured email reply. Match the formality of the email. Clear, purposeful, no fluff.',
  bold:         'Short, direct, punchy. No filler. Gets to the point.',
  witty:        'Smart and playful. A touch of dry humor. Never forced.',
}

const DECISIONS = `Before generating replies, assess:
1. Language and cultural dialect → reply in the exact same register, not translated English
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the last message implies → address it
5. Whether to advance the conversation or simply respond
6. For dating contexts: where are they in the relationship?`

const PREMIUM_REPLY_COUNT = 5

export interface LlmResult {
  replies: string[]
  summary: string
}

/** Parse LLM output that starts with an optional SUMMARY: line followed by numbered replies. */
export function parseLlmOutput(text: string): LlmResult {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  let summary = ''
  const replies: string[] = []

  for (const line of lines) {
    if (!summary && line.startsWith('SUMMARY:')) {
      summary = line.replace(/^SUMMARY:\s*/i, '').trim()
    } else if (/^\d+[.)]\s/.test(line)) {
      replies.push(line.replace(/^\d+[.)]\s*/, '').trim())
    }
  }

  return { replies, summary }
}

interface LlmCallParams {
  system: string
  user: string
  images: string[]
  model: Model
  anthropicKey: string
  openaiKey: string
}

interface LlmTextParams {
  system: string
  user: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

async function callLlm(params: LlmCallParams): Promise<LlmResult> {
  const { system, user, images, model, anthropicKey, openaiKey } = params

  if (model === 'claude') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const imageContent = images.map(b64 => ({
      type: 'image' as const,
      source: { type: 'base64' as const, media_type: 'image/png' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: [...imageContent, { type: 'text', text: user }] }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
  }

  const client = new OpenAI({ apiKey: openaiKey })
  const imageContent = images.map(b64 => ({
    type: 'image_url' as const,
    image_url: { url: `data:image/png;base64,${b64}` }
  }))
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}

async function callLlmText(params: LlmTextParams): Promise<LlmResult> {
  const { system, user, model, anthropicKey, openaiKey } = params

  if (model === 'claude') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: user }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
  }

  const client = new OpenAI({ apiKey: openaiKey })
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}

export interface GenerateEmailParams {
  emailText: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  tier: Tier
  anthropicKey: string
  openaiKey: string
}

export interface GenerateParams {
  screenshotBase64: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  tier: Tier
  anthropicKey: string
  openaiKey: string
}

export interface GenerateMultipleParams {
  screenshots: string[]
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

function buildContextBlock(summary?: string, previousContext?: string): string {
  const parts: string[] = []
  if (previousContext) {
    parts.push(`CONVERSATION MEMORY (earlier in this same conversation):\n${previousContext}`)
  }
  if (summary) {
    parts.push(`CONVERSATION BACKGROUND (from user):\n${summary}`)
  }
  return parts.length > 0 ? parts.join('\n\n') + '\n\n' : ''
}

function buildReplyFormat(count: number): string {
  return `Output format — exactly this, no other text:
SUMMARY: [one sentence: topic of conversation and what was last said]
${Array.from({ length: count }, (_, i) => `${i + 1}. [reply]`).join('\n')}`
}

export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, summary, previousContext, model, tier, anthropicKey, openaiKey } = params
  const count = tier === 'premium' ? PREMIUM_REPLY_COUNT : 3
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(count)}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey })
}

export async function generateRepliesFromMultiple(params: GenerateMultipleParams): Promise<LlmResult> {
  const { screenshots, tone, summary, previousContext, model, anthropicKey, openaiKey } = params
  const count = PREMIUM_REPLY_COUNT
  const toneInstruction = TONE_PROMPTS[tone] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}The following screenshots show a conversation scrolled through from bottom to top. Read all of them together to understand the full context.

Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(count)}`

  return callLlm({ system, user, images: screenshots, model, anthropicKey, openaiKey })
}

export async function generateRepliesFromEmail(params: GenerateEmailParams): Promise<LlmResult> {
  const { emailText, tone, summary, previousContext, model, tier, anthropicKey, openaiKey } = params
  const count = tier === 'premium' ? PREMIUM_REPLY_COUNT : 3
  const toneInstruction = TONE_PROMPTS[tone.toLowerCase()] ?? tone

  const system = [IDENTITY, `ROLE: ${toneInstruction}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}EMAIL TO REPLY TO:\n${emailText}\n\n${DECISIONS}\n\n${buildReplyFormat(count)}`

  return callLlmText({ system, user, model, anthropicKey, openaiKey })
}

/** Kept for any callers that still use the old signature — returns only replies. */
export function parseReplies(text: string): string[] {
  return parseLlmOutput(text).replies
}
```

- [ ] **Step 3: Update `reply.ts` to pass `previousContext` and return `summary`**

Replace `/Users/WORK2/Desktop/Replr/backend/src/routes/reply.ts`:

```typescript
import { Hono } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import { checkRateLimit } from '../services/rateLimit'
import type { Env, ReplyRequest, Model } from '../types'

export const replyRoute = new Hono<{ Bindings: Env }>()

replyRoute.post('/', async (c) => {
  let body: Partial<ReplyRequest>
  try {
    body = await c.req.json<Partial<ReplyRequest>>()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }
  const { screenshotBase64, emailText, tone, summary, previousContext, model, userId, transactionId } = body

  if ((!screenshotBase64 && !emailText) || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshotBase64 or emailText, tone, model, userId' }, 400)
  }

  if (model !== 'claude' && model !== 'gpt4o') {
    return c.json({ error: 'Invalid model. Must be "claude" or "gpt4o".' }, 400)
  }

  const tier = transactionId ? 'premium' : 'free'
  const limit = parseInt(c.env.FREE_DAILY_LIMIT ?? '20', 10)
  const allowed = await checkRateLimit(c.env.RATE_LIMIT_KV, userId, tier, limit)

  if (!allowed) {
    return c.json({ error: 'Daily limit reached. Upgrade to premium for unlimited replies.' }, 429)
  }

  try {
    const result = emailText
      ? await generateRepliesFromEmail({
          emailText, tone, summary, previousContext, model, tier,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
      : await generateReplies({
          screenshotBase64: screenshotBase64!, tone, summary, previousContext, model, tier,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary })
  } catch (err) {
    console.error('LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})

interface ScrollRequest {
  screenshots: string[]
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  userId: string
  transactionId?: string
}

replyRoute.post('/scroll', async (c) => {
  let body: Partial<ScrollRequest>
  try {
    body = await c.req.json<Partial<ScrollRequest>>()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshots, tone, model, userId, summary, previousContext, transactionId } = body

  if (!Array.isArray(screenshots) || screenshots.length === 0 || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshots, tone, model, userId' }, 400)
  }

  if (model !== 'claude' && model !== 'gpt4o') {
    return c.json({ error: 'Invalid model. Must be "claude" or "gpt4o".' }, 400)
  }

  if (screenshots.length > 6) {
    return c.json({ error: 'Too many screenshots. Maximum 6 allowed.' }, 400)
  }

  if (!transactionId) {
    return c.json({ error: 'Scroll capture requires premium.' }, 403)
  }

  const tier: 'premium' = 'premium'
  const limit = parseInt(c.env.FREE_DAILY_LIMIT ?? '20', 10)
  const allowed = await checkRateLimit(c.env.RATE_LIMIT_KV, userId, tier, limit)
  if (!allowed) {
    return c.json({ error: 'Daily limit reached. Upgrade to premium for unlimited replies.' }, 429)
  }

  try {
    const result = await generateRepliesFromMultiple({
      screenshots, tone, summary, previousContext, model,
      anthropicKey: c.env.ANTHROPIC_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary })
  } catch (err) {
    console.error('Scroll LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
```

- [ ] **Step 4: Build the backend**

```bash
cd /Users/WORK2/Desktop/Replr/backend
npx tsc --noEmit
```

Expected: no TypeScript errors.

- [ ] **Step 5: Deploy backend**

```bash
cd /Users/WORK2/Desktop/Replr/backend
npx wrangler deploy
```

Expected: `Deployed replr-api` with the worker URL.

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add backend/src/types/index.ts backend/src/services/llm.ts backend/src/routes/reply.ts
git commit -m "feat: backend returns LLM summary per session, accepts previousContext for memory"
```

---

### Task 3: iOS ReplyService + GenerateReplyIntent

**Files:**
- Modify: `Shared/Services/ReplyService.swift`
- Modify: `Shared/GenerateReplyIntent.swift`

- [ ] **Step 1: Update `ReplyService` — add `previousContext`, decode `summary`, return `ReplyResult`**

Replace `/Users/WORK2/Desktop/Replr/Shared/Services/ReplyService.swift`:

```swift
import Foundation
import UIKit

struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
    let transactionId: String?
}

struct ReplyEmailRequest: Codable {
    let emailText: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
    let transactionId: String?
}

struct ReplyResponse: Codable {
    let replies: [String]
    let summary: String?
}

struct ReplyResult {
    let replies: [String]
    let summary: String?
}

final class ReplyService {
    static let shared = ReplyService()

    private let session: URLSession
    private let backendURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        self.backendURL = URL(string: Constants.backendURL + "/reply")!
    }

    func generateReplies(
        screenshot: UIImage,
        tone: Tone,
        summary: String?,
        previousContext: String?,
        model: String,
        transactionId: String?
    ) async throws -> ReplyResult {
        guard let pngData = screenshot.pngData() else { throw ReplyError.encodingFailed }
        let base64 = pngData.base64EncodedString()

        let body = ReplyRequest(
            screenshotBase64: base64,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: model,
            userId: AppGroupService.shared.userID(),
            transactionId: transactionId
        )

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary)
    }

    func generateRepliesFromEmail(
        emailText: String,
        tone: Tone,
        summary: String?,
        previousContext: String?,
        model: String,
        transactionId: String?
    ) async throws -> ReplyResult {
        let body = ReplyEmailRequest(
            emailText: emailText,
            tone: tone.instruction,
            summary: summary,
            previousContext: previousContext,
            model: model,
            userId: AppGroupService.shared.userID(),
            transactionId: transactionId
        )

        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary)
    }

    func generateRepliesFromScroll(
        screenshots: [UIImage],
        tone: Tone,
        summary: String?,
        previousContext: String?,
        model: String,
        transactionId: String?
    ) async throws -> ReplyResult {
        let frames = screenshots.prefix(6).compactMap { $0.pngData()?.base64EncodedString() }
        guard !frames.isEmpty else { throw ReplyError.encodingFailed }

        let scrollURL = URL(string: Constants.backendURL + "/reply/scroll")!
        var request = URLRequest(url: scrollURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let payload: [String: Any?] = [
            "screenshots": frames,
            "tone": tone.instruction,
            "summary": summary,
            "previousContext": previousContext,
            "model": model,
            "userId": AppGroupService.shared.userID(),
            "transactionId": transactionId,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReplyError.invalidResponse }
        if http.statusCode == 429 { throw ReplyError.rateLimitReached }
        guard http.statusCode == 200 else { throw ReplyError.serverError(http.statusCode) }

        let decoded = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return ReplyResult(replies: decoded.replies, summary: decoded.summary)
    }
}

enum ReplyError: LocalizedError {
    case encodingFailed
    case invalidResponse
    case rateLimitReached
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:      return "Couldn't process the screenshot."
        case .invalidResponse:     return "Something went wrong. Tap Capture to retry."
        case .rateLimitReached:    return "Daily limit reached. Upgrade to premium for unlimited replies."
        case .serverError:         return "Something went wrong. Tap Capture to retry."
        }
    }
}
```

- [ ] **Step 2: Update `GenerateReplyIntent` — pass previous context, build and save session**

Replace `/Users/WORK2/Desktop/Replr/Shared/GenerateReplyIntent.swift`:

```swift
import AppIntents
import Photos
import UIKit

struct GenerateReplyIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Reply"
    static var description = IntentDescription("Reads your latest chat screenshot and prepares reply suggestions in the Replr keyboard.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        NSLog("[Replr][Intent] GenerateReplyIntent fired")
        AppGroupService.shared.isGenerating = true
        defer { AppGroupService.shared.isGenerating = false }

        let tone = AppGroupService.shared.readSelectedTone()
        let context = AppGroupService.shared.readPendingContext()
        let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)

        // Build previousContext from recent sessions (last 4 hours)
        let recentSummaries = AppGroupService.shared.activeSessionSummaries()
        let previousContext: String? = recentSummaries.isEmpty ? nil : recentSummaries.joined(separator: "\n")

        // Email tone: read from clipboard
        if tone.name.lowercased() == "email" {
            let clipboardText = UIPasteboard.general.string ?? ""
            guard !clipboardText.trimmingCharacters(in: .whitespaces).isEmpty else {
                NSLog("[Replr][Intent] Email tone but clipboard is empty")
                AppGroupService.shared.saveError("Copy the email text first, then triple-tap to generate a reply.")
                return .result()
            }
            NSLog("[Replr][Intent] Email mode — clipboard length: %d", clipboardText.count)
            do {
                let result = try await ReplyService.shared.generateRepliesFromEmail(
                    emailText: clipboardText,
                    tone: tone,
                    summary: context,
                    previousContext: previousContext,
                    model: "claude",
                    transactionId: txID
                )
                NSLog("[Replr][Intent] Got %d email replies", result.replies.count)
                let session = CaptureSession(
                    id: UUID(),
                    timestamp: Date(),
                    thumbnailData: nil,
                    contextHint: context,
                    generatedReplies: result.replies,
                    selectedReply: nil,
                    llmSummary: result.summary
                )
                AppGroupService.shared.appendCaptureSession(session)
                AppGroupService.shared.saveReplies(result.replies)
            } catch {
                NSLog("[Replr][Intent] Email API error: %@", error.localizedDescription)
                AppGroupService.shared.saveError(error.localizedDescription)
            }
            return .result()
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        NSLog("[Replr][Intent] Photos auth status: %d", status.rawValue)

        guard status == .authorized || status == .limited else {
            NSLog("[Replr][Intent] No Photos access — saving error")
            AppGroupService.shared.saveError("Allow photo access in Settings → Replr → Photos, then try again.")
            return .result()
        }

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        guard let asset = PHAsset.fetchAssets(with: .image, options: opts).firstObject else {
            NSLog("[Replr][Intent] No screenshot found in Photos")
            AppGroupService.shared.saveError("No screenshot found. Take a screenshot of your chat first.")
            return .result()
        }
        NSLog("[Replr][Intent] Found screenshot: creationDate=%@", asset.creationDate.map { "\($0)" } ?? "nil")

        let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            let reqOpts = PHImageRequestOptions()
            reqOpts.deliveryMode = .highQualityFormat
            reqOpts.isNetworkAccessAllowed = false
            reqOpts.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: reqOpts
            ) { image, info in
                if let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    continuation.resume(returning: image)
                } else if let image {
                    _ = image
                } else {
                    continuation.resume(throwing: GenerateReplyError.imageLoadFailed)
                }
            }
        }

        NSLog("[Replr][Intent] Image loaded: %.0fx%.0f", image.size.width, image.size.height)
        NSLog("[Replr][Intent] Calling API: tone=%@, hasContext=%d, hasPreviousContext=%d",
              tone.name, context != nil ? 1 : 0, previousContext != nil ? 1 : 0)

        do {
            let result = try await ReplyService.shared.generateReplies(
                screenshot: image,
                tone: tone,
                summary: context,
                previousContext: previousContext,
                model: "claude",
                transactionId: txID
            )
            NSLog("[Replr][Intent] Got %d replies — saving to App Group", result.replies.count)
            let thumbnail = makeThumbnail(image)
            let session = CaptureSession(
                id: UUID(),
                timestamp: Date(),
                thumbnailData: thumbnail,
                contextHint: context,
                generatedReplies: result.replies,
                selectedReply: nil,
                llmSummary: result.summary
            )
            AppGroupService.shared.appendCaptureSession(session)
            AppGroupService.shared.saveReplies(result.replies)
        } catch {
            NSLog("[Replr][Intent] API error: %@", error.localizedDescription)
            AppGroupService.shared.saveError(error.localizedDescription)
        }

        return .result()
    }

    // Scale screenshot down to ~80px wide JPEG for storage in App Group
    private func makeThumbnail(_ image: UIImage) -> Data? {
        let targetWidth: CGFloat = 80
        guard image.size.width > 0 else { return nil }
        let scale = targetWidth / image.size.width
        let size = CGSize(width: targetWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumb = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return thumb.jpegData(compressionQuality: 0.4)
    }
}

enum GenerateReplyError: Error {
    case imageLoadFailed
}
```

- [ ] **Step 3: Build and confirm no errors**

In Xcode, select the main Replr target and press ⌘B. Expected: build succeeds. Fix any "extra argument" errors by confirming `generateReplies` call sites in other intent files (e.g. `QuickReplyIntent.swift`) also pass `previousContext: nil`.

- [ ] **Step 4: Check `QuickReplyIntent.swift` and `AnalyzeScreenshotIntent.swift` for broken call sites**

Run:

```bash
grep -rn "generateReplies\|generateRepliesFromEmail" /Users/WORK2/Desktop/Replr/Replr/Replr/Intents/ /Users/WORK2/Desktop/Replr/Shared/
```

For any call that now misses the `previousContext` argument, add `previousContext: nil`.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add Shared/Services/ReplyService.swift Shared/GenerateReplyIntent.swift
git commit -m "feat: iOS sends previousContext to API and saves CaptureSession after each generation"
```

---

### Task 4: Keyboard records selected reply

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Mark selected reply on session in `insert()`**

In `/Users/WORK2/Desktop/Replr/ReplrKeyboard/KeyboardViewController.swift`, update `insert()`:

```swift
private func insert(_ text: String) {
    let ctx = textDocumentProxy.documentContextBeforeInput ?? ""
    for _ in ctx.unicodeScalars { textDocumentProxy.deleteBackward() }
    textDocumentProxy.insertText(text)
    model.pendingContext = ""
    AppGroupService.shared.savePendingContext("")
    AppGroupService.shared.markLastSessionReplySelected(text)
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
```

- [ ] **Step 2: Build the keyboard extension target**

In Xcode, select the `ReplrKeyboard` target and press ⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: record selected reply on most recent capture session"
```

---

### Task 5: Companion app — Captures tab

**Files:**
- Create: `Replr/Replr/Features/Captures/CaptureLogView.swift`
- Modify: `Replr/Replr/App/ReplrApp.swift`

- [ ] **Step 1: Create `CaptureLogView`**

Create `/Users/WORK2/Desktop/Replr/Replr/Replr/Features/Captures/CaptureLogView.swift`:

```swift
import SwiftUI

final class CaptureLogViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []

    func load() {
        sessions = AppGroupService.shared.loadCaptureSessions().reversed()
    }

    func clearAll() {
        AppGroupService.shared.clearCaptureSessions()
        sessions = []
    }

    func delete(at offsets: IndexSet) {
        // offsets are into the reversed array; map back, remove, re-save
        var all = AppGroupService.shared.loadCaptureSessions()
        let totalCount = all.count
        let allOffsets = IndexSet(offsets.map { totalCount - 1 - $0 })
        all.remove(atOffsets: allOffsets)
        AppGroupService.shared.saveCaptureSessions(all)
        sessions.remove(atOffsets: offsets)
    }
}

struct CaptureLogView: View {
    @StateObject private var vm = CaptureLogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.sessions.isEmpty {
                    ContentUnavailableView(
                        "No captures yet",
                        systemImage: "camera.viewfinder",
                        description: Text("Generate replies from the Replr keyboard to see them here.")
                    )
                } else {
                    List {
                        ForEach(vm.sessions) { session in
                            NavigationLink(destination: CaptureDetailView(session: session)) {
                                CaptureRowView(session: session)
                            }
                        }
                        .onDelete(perform: vm.delete)
                    }
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                if !vm.sessions.isEmpty {
                    Button(role: .destructive) { vm.clearAll() } label: {
                        Text("Clear All")
                    }
                }
            }
        }
        .onAppear { vm.load() }
    }
}

struct CaptureRowView: View {
    let session: CaptureSession

    var body: some View {
        HStack(spacing: 12) {
            if let data = session.thumbnailData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 64)
                    .overlay(Image(systemName: "text.bubble").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let summary = session.llmSummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                if let selected = session.selectedReply {
                    Text("Sent: \(selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CaptureDetailView: View {
    let session: CaptureSession

    var body: some View {
        List {
            Section("Screenshot") {
                if let data = session.thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("No screenshot (email capture)")
                        .foregroundStyle(.secondary)
                }
            }

            if let summary = session.llmSummary {
                Section("Conversation Summary") {
                    Text(summary)
                }
            }

            if let hint = session.contextHint {
                Section("Context Provided") {
                    Text(hint)
                }
            }

            Section("Generated Replies") {
                ForEach(session.generatedReplies, id: \.self) { reply in
                    HStack {
                        Text(reply)
                        if reply == session.selectedReply {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.timestamp, style: .date)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Add Captures tab to `ContentView`**

In `/Users/WORK2/Desktop/Replr/Replr/Replr/App/ReplrApp.swift`, update `ContentView.body`:

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            CaptureLogView()
                .tabItem { Label("Captures", systemImage: "camera.viewfinder") }
            SummariesView()
                .tabItem { Label("Summaries", systemImage: "bubble.left.and.bubble.right") }
            TonesView()
                .tabItem { Label("Tones", systemImage: "slider.horizontal.3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            let txID = await SubscriptionManager.shared.currentTransactionID()
            UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
        }
    }
}
```

- [ ] **Step 3: Build the main Replr target**

In Xcode, select the `Replr` target and press ⌘B. Expected: build succeeds. If `ContentUnavailableView` causes a deployment target error (requires iOS 17), replace with:

```swift
VStack(spacing: 16) {
    Image(systemName: "camera.viewfinder")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
    Text("No captures yet")
        .font(.headline)
    Text("Generate replies from the Replr keyboard to see them here.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
}
```

- [ ] **Step 4: Run on device or simulator and verify the Captures tab appears**

Expected: Captures tab shows "No captures yet". After generating a reply via keyboard, reopen companion app — session appears with thumbnail, summary, and replied-with indicator.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/Replr
git add Replr/Replr/Features/Captures/CaptureLogView.swift Replr/Replr/App/ReplrApp.swift
git commit -m "feat: add Captures tab in companion app showing session log with thumbnails and summaries"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Capture visibility in companion app → Task 5
- ✅ Screenshot thumbnail stored per session → Task 3 (`makeThumbnail`)
- ✅ LLM-extracted summary per session → Task 2 (`SUMMARY:` line), Task 3 (stored in `CaptureSession`)
- ✅ Previous session summaries fed into next generation → Task 3 (`activeSessionSummaries()` → `previousContext`)
- ✅ 4-hour conversation window for memory → Task 1 (`conversationWindowSeconds`)
- ✅ Selected reply recorded → Task 4
- ✅ Clear all sessions → Task 5 (Clear All button)
- ✅ Backend deployed → Task 2 Step 5

**Placeholder scan:** None found. All code blocks are complete.

**Type consistency check:**
- `CaptureSession` defined in Task 1, used in Tasks 3, 4, 5 — consistent
- `ReplyResult` defined in Task 3 `ReplyService`, returned by all three generate methods, consumed in `GenerateReplyIntent` — consistent
- `activeSessionSummaries() -> [String]` defined in Task 1, called in Task 3 — consistent
- `markLastSessionReplySelected(_ reply: String)` defined in Task 1, called in Task 4 — consistent
- `appendCaptureSession(_ session: CaptureSession)` defined in Task 1, called in Task 3 — consistent
