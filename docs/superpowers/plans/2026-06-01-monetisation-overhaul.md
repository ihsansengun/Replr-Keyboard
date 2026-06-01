# Monetisation Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace subscription + trial system with pay-as-you-go credit packs, add 4-model support (GPT-4.1-mini default), dev mode for unlimited testing, and JPEG screenshot compression.

**Architecture:** Backend gains a model router mapping 4 model IDs to OpenAI/Anthropic providers, removes all tier logic (always 5 replies). iOS gains `CreditsManager` (replaces `SubscriptionManager`), `ReplrModel` enum, `CreditPacksView`, and a hidden dev `ModelPickerView`. Credit balance lives in App Group so keyboard extension and companion app share it. Migration from trial/subscription runs once on first launch.

**Tech Stack:** Swift 5.9, SwiftUI, StoreKit 2, TypeScript, Hono (Cloudflare Workers), Anthropic SDK, OpenAI SDK

---

## File Map

**Backend — modified:**
| File | Change |
|---|---|
| `backend/src/types/index.ts` | `Model` type → 4 IDs, remove `Tier` |
| `backend/src/services/llm.ts` | Add `resolveModel()`, remove tier, always 5 replies |
| `backend/src/routes/reply.ts` | New model validation, remove transactionId/tier logic |

**iOS — new files:**
| File | Purpose |
|---|---|
| `Replr/Replr/Credits/ReplrModel.swift` | Enum: 4 models with credits/display/API ID |
| `Replr/Replr/Credits/CreditsManager.swift` | StoreKit 2 consumables, balance, migration |
| `Replr/Replr/Credits/CreditPacksView.swift` | Purchase UI (4 packs) |
| `Replr/Replr/Features/Settings/ModelPickerView.swift` | Dev-only model selector |

**iOS — modified:**
| File | Change |
|---|---|
| `Shared/Constants.swift` | Add `creditBalanceKey`, `selectedModelKey`, `devModeKey`, `creditsMigratedKey` |
| `Shared/AppGroupService.swift` | Add `creditBalance`, `selectedModel`, `devMode` properties |
| `Shared/ReplyService.swift` | JPEG compression, remove `transactionId`, use `selectedModel` from AppGroup |
| `Replr/Replr/Intents/GenerateReplyIntent.swift` | Credit gate (replaces trial gate) |
| `ReplrKeyboard/Views/KeyboardView.swift` | Credit counter (replaces trial counter), dev mode ∞ badge |
| `ReplrKeyboard/KeyboardViewController.swift` | Check `creditBalance == 0` not `trialExhausted` |
| `Replr/Replr/App/ReplrApp.swift` | Use `CreditsManager`, present `CreditPacksView` at 0 credits |
| `Replr/Replr/Features/Settings/SettingsView.swift` | Link to `CreditPacksView`, long-press version → `ModelPickerView` |

**iOS — deleted:**
- `Replr/Replr/Subscription/SubscriptionManager.swift`
- `Replr/Replr/Subscription/PaywallView.swift`

---

## Task 1: Backend — Update types/index.ts

**Files:**
- Modify: `backend/src/types/index.ts`

- [ ] **Step 1: Replace Model type and remove Tier**

Replace the entire file content:

```typescript
export type Model = 'gpt-4.1-mini' | 'gpt-5.4-mini' | 'gpt-4.1' | 'claude-sonnet-4-6'

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
  previousContext?: string
  model: Model
  userId: string
}

export interface ReplyResponse {
  replies: string[]
  summary: string
  contactName: string
}
```

- [ ] **Step 2: Typecheck**

```bash
cd backend && npm run typecheck
```
Expected: no errors (may show errors in llm.ts/reply.ts — those are fixed in Tasks 2-3).

- [ ] **Step 3: Commit**

```bash
git add backend/src/types/index.ts
git commit -m "feat(backend): update Model type to 4 model IDs, remove Tier"
```

---

## Task 2: Backend — Refactor llm.ts model router

**Files:**
- Modify: `backend/src/services/llm.ts`

- [ ] **Step 1: Update imports and remove Tier**

Replace the first line:
```typescript
import type { Model, Tier } from '../types'
```
With:
```typescript
import type { Model } from '../types'
```

- [ ] **Step 2: Remove PREMIUM_REPLY_COUNT constant and replace with fixed 5**

Remove:
```typescript
const PREMIUM_REPLY_COUNT = 5
```
Add after the `DECISIONS` constant:
```typescript
const REPLY_COUNT = 5
```

- [ ] **Step 3: Add resolveModel function after the DECISIONS block**

After the `DECISIONS` constant, add:

```typescript
interface ModelResolution {
  provider: 'openai' | 'anthropic'
  apiModel: string
}

function resolveModel(model: Model): ModelResolution {
  switch (model) {
    case 'gpt-4.1-mini':      return { provider: 'openai',    apiModel: 'gpt-4.1-mini' }
    case 'gpt-5.4-mini':      return { provider: 'openai',    apiModel: 'gpt-5.4-mini' }
    case 'gpt-4.1':           return { provider: 'openai',    apiModel: 'gpt-4.1' }
    case 'claude-sonnet-4-6': return { provider: 'anthropic', apiModel: 'claude-sonnet-4-6' }
  }
}
```

- [ ] **Step 4: Update callLlm to use resolveModel**

Replace the entire `callLlm` function:

```typescript
async function callLlm(params: LlmCallParams): Promise<LlmResult> {
  const { system, user, images, model, anthropicKey, openaiKey } = params
  const { provider, apiModel } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const imageContent = images.map(b64 => ({
      type: 'image' as const,
      source: { type: 'base64' as const, media_type: 'image/jpeg' as const, data: b64 }
    }))
    const response = await client.messages.create({
      model: apiModel,
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
    image_url: { url: `data:image/jpeg;base64,${b64}` }
  }))
  const response = await client.chat.completions.create({
    model: apiModel,
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: [...imageContent, { type: 'text', text: user }] as any },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}
```

Note: `media_type` changed from `image/png` to `image/jpeg` to match iOS JPEG compression (Task 8).

- [ ] **Step 5: Update callLlmText to use resolveModel**

Replace the entire `callLlmText` function:

```typescript
async function callLlmText(params: LlmTextParams): Promise<LlmResult> {
  const { system, user, model, anthropicKey, openaiKey } = params
  const { provider, apiModel } = resolveModel(model)

  if (provider === 'anthropic') {
    const client = new Anthropic({ apiKey: anthropicKey })
    const response = await client.messages.create({
      model: apiModel,
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: user }],
    })
    const textBlock = response.content.find(b => b.type === 'text')
    return parseLlmOutput(textBlock && 'text' in textBlock ? textBlock.text : '')
  }

  const client = new OpenAI({ apiKey: openaiKey })
  const response = await client.chat.completions.create({
    model: apiModel,
    max_tokens: 1024,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  })
  return parseLlmOutput(response.choices[0].message.content ?? '')
}
```

- [ ] **Step 6: Update GenerateParams and GenerateEmailParams — remove tier**

Find `export interface GenerateParams` and remove the `tier: Tier` line.
Find `export interface GenerateEmailParams` and remove the `tier: Tier` line.

```typescript
export interface GenerateParams {
  screenshotBase64: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
}

export interface GenerateEmailParams {
  emailText: string
  tone: string
  summary?: string
  previousContext?: string
  model: Model
  anthropicKey: string
  openaiKey: string
}
```

- [ ] **Step 7: Update generateReplies — remove tier, always REPLY_COUNT replies**

Replace `generateReplies`:

```typescript
export async function generateReplies(params: GenerateParams): Promise<LlmResult> {
  const { screenshotBase64, tone, summary, previousContext, model, anthropicKey, openaiKey } = params

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}Reading guide:
- Bubbles on the RIGHT = sent by the user
- Bubbles on the LEFT = sent by the other person

${DECISIONS}

${buildReplyFormat(REPLY_COUNT)}`

  return callLlm({ system, user, images: [screenshotBase64], model, anthropicKey, openaiKey })
}
```

- [ ] **Step 8: Update generateRepliesFromMultiple — use REPLY_COUNT**

Replace `const count = PREMIUM_REPLY_COUNT` with `const count = REPLY_COUNT` in `generateRepliesFromMultiple`.

- [ ] **Step 9: Update generateRepliesFromEmail — remove tier**

Replace `generateRepliesFromEmail`:

```typescript
export async function generateRepliesFromEmail(params: GenerateEmailParams): Promise<LlmResult> {
  const { emailText, tone, summary, previousContext, model, anthropicKey, openaiKey } = params

  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')

  const user = `${buildContextBlock(summary, previousContext)}EMAIL TO REPLY TO:\n${emailText}\n\n${DECISIONS}\n\n${buildReplyFormat(REPLY_COUNT)}`

  return callLlmText({ system, user, model, anthropicKey, openaiKey })
}
```

- [ ] **Step 10: Typecheck**

```bash
cd backend && npm run typecheck
```
Expected: no errors (reply.ts still has errors — fixed in Task 3).

- [ ] **Step 11: Commit**

```bash
git add backend/src/services/llm.ts
git commit -m "feat(backend): add resolveModel router, remove tier, always 5 replies, JPEG media type"
```

---

## Task 3: Backend — Update reply.ts

**Files:**
- Modify: `backend/src/routes/reply.ts`

- [ ] **Step 1: Update imports**

Replace:
```typescript
import type { Env, ReplyRequest, Model } from '../types'
```
With:
```typescript
import type { Env, Model } from '../types'
```

Remove the `checkRateLimit` import line entirely:
```typescript
import { checkRateLimit } from '../services/rateLimit'
```

- [ ] **Step 2: Replace the POST / handler**

Replace the entire `replyRoute.post('/', ...)` handler:

```typescript
const VALID_MODELS: Model[] = ['gpt-4.1-mini', 'gpt-5.4-mini', 'gpt-4.1', 'claude-sonnet-4-6']

replyRoute.post('/', async (c) => {
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshotBase64, emailText, tone, summary, previousContext, model, userId } =
    body as Record<string, string | undefined>

  if ((!screenshotBase64 && !emailText) || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshotBase64 or emailText, tone, model, userId' }, 400)
  }

  if (!VALID_MODELS.includes(model as Model)) {
    return c.json({ error: `Invalid model. Must be one of: ${VALID_MODELS.join(', ')}` }, 400)
  }

  try {
    const result = emailText
      ? await generateRepliesFromEmail({
          emailText, tone, summary, previousContext,
          model: model as Model,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
      : await generateReplies({
          screenshotBase64: screenshotBase64!,
          tone, summary, previousContext,
          model: model as Model,
          anthropicKey: c.env.ANTHROPIC_API_KEY,
          openaiKey: c.env.OPENAI_API_KEY,
        })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName })
  } catch (err) {
    console.error('LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
```

- [ ] **Step 3: Replace the POST /scroll handler**

Remove the `ScrollRequest` interface and replace the `replyRoute.post('/scroll', ...)` handler:

```typescript
replyRoute.post('/scroll', async (c) => {
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { screenshots, tone, model, userId, summary, previousContext } =
    body as { screenshots?: string[], tone?: string, model?: string, userId?: string, summary?: string, previousContext?: string }

  if (!Array.isArray(screenshots) || screenshots.length === 0 || !tone || !model || !userId) {
    return c.json({ error: 'Missing required fields: screenshots, tone, model, userId' }, 400)
  }

  if (!VALID_MODELS.includes(model as Model)) {
    return c.json({ error: `Invalid model. Must be one of: ${VALID_MODELS.join(', ')}` }, 400)
  }

  if (screenshots.length > 6) {
    return c.json({ error: 'Too many screenshots. Maximum 6 allowed.' }, 400)
  }

  try {
    const result = await generateRepliesFromMultiple({
      screenshots, tone, summary, previousContext,
      model: model as Model,
      anthropicKey: c.env.ANTHROPIC_API_KEY,
      openaiKey: c.env.OPENAI_API_KEY,
    })
    if (result.replies.length === 0) {
      return c.json({ error: 'Could not parse replies. Please try again.' }, 502)
    }
    return c.json({ replies: result.replies, summary: result.summary, contactName: result.contactName })
  } catch (err) {
    console.error('Scroll LLM error:', err)
    return c.json({ error: 'Failed to generate replies. Please try again.' }, 500)
  }
})
```

- [ ] **Step 4: Typecheck and test**

```bash
cd backend && npm run typecheck && npm test
```
Expected: typecheck passes, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/reply.ts
git commit -m "feat(backend): remove tier/transactionId, validate 4 model IDs, scroll open to all"
```

---

## Task 4: Backend — Deploy

- [ ] **Step 1: Deploy to Cloudflare Workers**

```bash
cd backend && npm run deploy
```
Expected: Deployment successful.

- [ ] **Step 2: Smoke test — verify new model IDs work**

```bash
curl -s -X POST https://api.replr.app/reply \
  -H "Content-Type: application/json" \
  -d '{"emailText":"Test","tone":"casual","model":"gpt-4.1-mini","userId":"test-smoke"}' \
  | jq '.replies | length'
```
Expected: `5`

- [ ] **Step 3: Verify old model IDs are rejected**

```bash
curl -s -X POST https://api.replr.app/reply \
  -H "Content-Type: application/json" \
  -d '{"emailText":"Test","tone":"casual","model":"claude","userId":"test"}' \
  | jq '.error'
```
Expected: `"Invalid model. Must be one of: gpt-4.1-mini, gpt-5.4-mini, gpt-4.1, claude-sonnet-4-6"`

---

## Task 5: iOS — Add Constants keys

**Files:**
- Modify: `Shared/Constants.swift`

- [ ] **Step 1: Add 4 new keys after the existing trial keys**

After `static let paywallRequestedKey`:

```swift
// Credits + model + dev mode
static let creditBalanceKey   = "replr.credits.balance"
static let selectedModelKey   = "replr.credits.model"
static let devModeKey         = "replr.dev.mode"
static let creditsMigratedKey = "replr.credits.migrated"
```

- [ ] **Step 2: Build to confirm**

⌘B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add Shared/Constants.swift
git commit -m "feat: add credit, model, devMode, migration keys to Constants"
```

---

## Task 6: iOS — Add credit/model/devMode properties to AppGroupService

**Files:**
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add properties after the existing `// MARK: - Trial + paywall` section**

Add a new section:

```swift
// MARK: - Credits + model selection + dev mode

var creditBalance: Int {
    get { defaults.integer(forKey: Constants.creditBalanceKey) }
    set { defaults.set(newValue, forKey: Constants.creditBalanceKey); defaults.synchronize() }
}

var selectedModel: String {
    get { defaults.string(forKey: Constants.selectedModelKey) ?? "gpt-4.1-mini" }
    set { defaults.set(newValue, forKey: Constants.selectedModelKey); defaults.synchronize() }
}

var devMode: Bool {
    get { defaults.bool(forKey: Constants.devModeKey) }
    set { defaults.set(newValue, forKey: Constants.devModeKey); defaults.synchronize() }
}

/// Returns 9_999 in dev mode so the keyboard never shows a paywall during testing.
var effectiveCreditBalance: Int {
    devMode ? 9_999 : creditBalance
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add Shared/AppGroupService.swift
git commit -m "feat: add creditBalance, selectedModel, devMode, effectiveCreditBalance to AppGroupService"
```

---

## Task 7: iOS — Create ReplrModel.swift

**Files:**
- Create: `Replr/Replr/Credits/ReplrModel.swift`

- [ ] **Step 1: Create the Credits folder and file**

Create the directory `Replr/Replr/Credits/` and write the file:

```swift
import Foundation

enum ReplrModel: String, CaseIterable, Identifiable {
    case gpt4_1mini     = "gpt-4.1-mini"
    case gpt5_4mini     = "gpt-5.4-mini"
    case gpt4_1         = "gpt-4.1"
    case claudeSonnet   = "claude-sonnet-4-6"

    var id: String { rawValue }

    /// Human-readable name shown in dev picker.
    var displayName: String {
        switch self {
        case .gpt4_1mini:   return "GPT-4.1 Mini"
        case .gpt5_4mini:   return "GPT-5.4 Mini"
        case .gpt4_1:       return "GPT-4.1"
        case .claudeSonnet: return "Claude Sonnet 4.6"
        }
    }

    /// Credits deducted per request.
    var creditsPerRequest: Int {
        switch self {
        case .gpt4_1mini:   return 1
        case .gpt5_4mini:   return 2
        case .gpt4_1:       return 3
        case .claudeSonnet: return 3
        }
    }

    /// Model ID sent to the backend API.
    var apiModelID: String { rawValue }

    /// The default model used for all users.
    static let defaultModel: ReplrModel = .gpt4_1mini

    /// Init from an API model ID string stored in App Group.
    init?(apiID: String) {
        self.init(rawValue: apiID)
    }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded (file auto-included via Xcode 15 file-system sync).

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Credits/ReplrModel.swift"
git commit -m "feat: add ReplrModel enum — 4 models with credits/displayName/apiID"
```

---

## Task 8: iOS — JPEG compression in ReplyService.swift

**Files:**
- Modify: `Shared/ReplyService.swift`

- [ ] **Step 1: Add JPEG compression helper at the bottom of the file, before the closing brace**

After the `ReplyError` enum, add:

```swift
// MARK: - Image preprocessing

private func compressForUpload(_ image: UIImage) -> Data {
    // JPEG at 82% quality: ~5x smaller payload, no visible quality loss for text.
    // Compression runs here (at send time) rather than at capture time since
    // ReplyService is the single encoding point for both intent and keyboard flows.
    image.jpegData(compressionQuality: 0.82) ?? (image.pngData() ?? Data())
}
```

- [ ] **Step 2: Update generateReplies to use JPEG compression**

Find:
```swift
guard let pngData = screenshot.pngData() else { throw ReplyError.encodingFailed }
let base64 = pngData.base64EncodedString()
```

Replace with:
```swift
let imageData = compressForUpload(screenshot)
guard !imageData.isEmpty else { throw ReplyError.encodingFailed }
let base64 = imageData.base64EncodedString()
```

- [ ] **Step 3: Update generateRepliesFromScroll to use JPEG compression**

Find:
```swift
let frames = screenshots.prefix(6).compactMap { $0.pngData()?.base64EncodedString() }
```

Replace with:
```swift
let frames = screenshots.prefix(6).map { compressForUpload($0).base64EncodedString() }
```

- [ ] **Step 4: Remove transactionId from ReplyRequest and ReplyEmailRequest**

Find and update `ReplyRequest`:
```swift
struct ReplyRequest: Codable {
    let screenshotBase64: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
}
```

Find and update `ReplyEmailRequest`:
```swift
struct ReplyEmailRequest: Codable {
    let emailText: String
    let tone: String
    let summary: String?
    let previousContext: String?
    let model: String
    let userId: String
}
```

- [ ] **Step 5: Update generateReplies signature and body — remove transactionId, read model from AppGroup**

Replace the `generateReplies` function signature and body:

```swift
func generateReplies(
    screenshot: UIImage,
    tone: Tone,
    summary: String?,
    previousContext: String?
) async throws -> ReplyResult {
    let imageData = compressForUpload(screenshot)
    guard !imageData.isEmpty else { throw ReplyError.encodingFailed }
    let base64 = imageData.base64EncodedString()

    let body = ReplyRequest(
        screenshotBase64: base64,
        tone: tone.instruction,
        summary: summary,
        previousContext: previousContext,
        model: AppGroupService.shared.selectedModel,
        userId: AppGroupService.shared.userID()
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
    return ReplyResult(replies: decoded.replies, summary: decoded.summary, contactName: decoded.contactName)
}
```

- [ ] **Step 6: Update generateRepliesFromEmail signature — remove transactionId**

Replace:
```swift
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
```

With:
```swift
func generateRepliesFromEmail(
    emailText: String,
    tone: Tone,
    summary: String?,
    previousContext: String?
) async throws -> ReplyResult {
    let body = ReplyEmailRequest(
        emailText: emailText,
        tone: tone.instruction,
        summary: summary,
        previousContext: previousContext,
        model: AppGroupService.shared.selectedModel,
        userId: AppGroupService.shared.userID()
    )
```

- [ ] **Step 7: Update generateRepliesFromScroll signature and body — remove transactionId**

Replace:
```swift
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
```

With:
```swift
func generateRepliesFromScroll(
    screenshots: [UIImage],
    tone: Tone,
    summary: String?,
    previousContext: String?
) async throws -> ReplyResult {
    let frames = screenshots.prefix(6).map { compressForUpload($0).base64EncodedString() }
    guard !frames.isEmpty else { throw ReplyError.encodingFailed }

    let scrollURL = URL(string: Constants.backendURL + "/reply/scroll")!
    var request = URLRequest(url: scrollURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 45

    let payload: [String: Any] = [
        "screenshots": frames,
        "tone": tone.instruction,
        "summary": summary as Any,
        "previousContext": previousContext as Any,
        "model": AppGroupService.shared.selectedModel,
        "userId": AppGroupService.shared.userID(),
    ].filter { !($0.value is Optional<Any>) || Mirror(reflecting: $0.value).displayStyle == .optional }
    // Cleaner: use Codable instead of dictionary
    struct ScrollRequest: Encodable {
        let screenshots: [String]
        let tone: String
        let summary: String?
        let previousContext: String?
        let model: String
        let userId: String
    }
    let scrollBody = ScrollRequest(
        screenshots: frames,
        tone: tone.instruction,
        summary: summary,
        previousContext: previousContext,
        model: AppGroupService.shared.selectedModel,
        userId: AppGroupService.shared.userID()
    )
    request.httpBody = try JSONEncoder().encode(scrollBody)
```

- [ ] **Step 8: Build to confirm — fix any callers with updated signature**

⌘B. Fix any compilation errors where old `generateReplies(screenshot:tone:summary:previousContext:model:transactionId:)` is called. Callers that need updating: `GenerateReplyIntent.swift`, `KeyboardModel.generateEmailReply()`. Update those call sites to match the new no-`transactionId` signatures.

In `GenerateReplyIntent.swift`, find:
```swift
let result = try await ReplyService.shared.generateReplies(
    screenshot: image,
    tone: tone.tone,
    summary: context,
    previousContext: previousContext,
    model: "claude",
    transactionId: txID
)
```
Replace with:
```swift
let result = try await ReplyService.shared.generateReplies(
    screenshot: image,
    tone: tone.tone,
    summary: context,
    previousContext: previousContext
)
```

In `KeyboardView.swift` (`generateEmailReply`), find any call to `generateRepliesFromEmail` and remove `model:` and `transactionId:` parameters.

- [ ] **Step 9: Build succeeds**

⌘B. Expected: Build Succeeded.

- [ ] **Step 10: Commit**

```bash
git add Shared/ReplyService.swift Replr/Replr/Intents/GenerateReplyIntent.swift ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: JPEG compression in ReplyService, remove transactionId, model from AppGroup"
```

---

## Task 9: iOS — Create CreditsManager.swift

**Files:**
- Create: `Replr/Replr/Credits/CreditsManager.swift`

- [ ] **Step 1: Write CreditsManager**

```swift
import StoreKit
import Foundation

@MainActor
final class CreditsManager: ObservableObject {
    static let shared = CreditsManager()

    @Published var balance: Int = 0
    @Published var products: [Product] = []
    @Published var isPurchasing = false

    private let productIDs = [
        "Theory-of-Web.Replr.credits.100",
        "Theory-of-Web.Replr.credits.300",
        "Theory-of-Web.Replr.credits.750",
        "Theory-of-Web.Replr.credits.2500",
    ]

    private init() {
        migrateIfNeeded()
        balance = AppGroupService.shared.effectiveCreditBalance
    }

    // MARK: - StoreKit

    func load() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            NSLog("[Credits] StoreKit load error: %@", error.localizedDescription)
        }
    }

    func purchase(_ product: Product) async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return }
            let credits = creditsForProductID(transaction.productID)
            AppGroupService.shared.creditBalance += credits
            balance = AppGroupService.shared.effectiveCreditBalance
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        isPurchasing = false
    }

    // MARK: - Balance

    func deduct(_ credits: Int) {
        guard !AppGroupService.shared.devMode else { return }
        AppGroupService.shared.creditBalance = max(0, AppGroupService.shared.creditBalance - credits)
        balance = AppGroupService.shared.creditBalance
    }

    func refreshBalance() {
        balance = AppGroupService.shared.effectiveCreditBalance
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let defaults = UserDefaults(suiteName: Constants.appGroupID)!
        guard !defaults.bool(forKey: Constants.creditsMigratedKey) else { return }

        // Convert remaining trial credits
        let trialUsed = defaults.integer(forKey: Constants.trialUsedCountKey)
        let remaining = max(0, 10 - trialUsed)
        if remaining > 0 {
            AppGroupService.shared.creditBalance += remaining
        }

        // Goodwill: 1,000 credits for existing premium subscribers
        if let txID = defaults.string(forKey: Constants.transactionIDKey), !txID.isEmpty {
            AppGroupService.shared.creditBalance += 1_000
        }

        defaults.set(true, forKey: Constants.creditsMigratedKey)
        defaults.synchronize()
        NSLog("[Credits] Migration complete. Balance: %d", AppGroupService.shared.creditBalance)
    }

    // MARK: - Helpers

    private func creditsForProductID(_ productID: String) -> Int {
        switch productID {
        case "Theory-of-Web.Replr.credits.100":  return 100
        case "Theory-of-Web.Replr.credits.300":  return 300
        case "Theory-of-Web.Replr.credits.750":  return 750
        case "Theory-of-Web.Replr.credits.2500": return 2_500
        default: return 0
        }
    }

    func creditsRequired(for modelID: String) -> Int {
        ReplrModel(apiID: modelID)?.creditsPerRequest ?? 1
    }

    /// Display string for balance: "∞" in dev mode, number otherwise.
    var balanceDisplay: String {
        AppGroupService.shared.devMode ? "∞" : "\(balance)"
    }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Credits/CreditsManager.swift"
git commit -m "feat: add CreditsManager — StoreKit consumables, balance, migration, dev mode"
```

---

## Task 10: iOS — Create CreditPacksView.swift

**Files:**
- Create: `Replr/Replr/Credits/CreditPacksView.swift`

- [ ] **Step 1: Write CreditPacksView**

```swift
import SwiftUI
import StoreKit

struct CreditPacksView: View {
    var showCloseButton: Bool = false

    @StateObject private var manager = CreditsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if showCloseButton {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                ScrollView {
                    VStack(spacing: 28) {
                        // Hero
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text("✦")
                                    .font(.system(size: 18))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("Get More Replies")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                            }
                            Text("Credits never expire. Use whenever you need.")
                                .font(.system(size: 14))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.top, showCloseButton ? 8 : 40)

                        // Balance
                        if manager.balance > 0 || AppGroupService.shared.devMode {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(ReplrTheme.Color.accent)
                                Text("\(manager.balanceDisplay) credits remaining")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ReplrTheme.Color.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ReplrTheme.Color.accentSubtle)
                            .clipShape(Capsule())
                        }

                        // Pack cards
                        if manager.products.isEmpty {
                            ProgressView()
                                .tint(ReplrTheme.Color.accent)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(manager.products, id: \.id) { product in
                                    PackCard(product: product) {
                                        Task {
                                            do {
                                                try await manager.purchase(product)
                                                errorMessage = nil
                                                if showCloseButton { dismiss() }
                                            } catch {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    }
                                    .disabled(manager.isPurchasing)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(ReplrTheme.Color.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Footer
                        VStack(spacing: 8) {
                            Button("Restore Purchases") { Task { await manager.restore() } }
                                .font(.system(size: 13))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)

                            HStack(spacing: 12) {
                                Link("Terms", destination: URL(string: "https://replr.app/terms")!)
                                Text("·").foregroundStyle(ReplrTheme.Color.textSecondary)
                                Link("Privacy", destination: URL(string: "https://replr.app/privacy")!)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.load() }
    }
}

private struct PackCard: View {
    let product: Product
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.textPrimary)
                Text("1 credit = 1 reply suggestion")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            Spacer()
            Button(action: onBuy) {
                Text(product.displayPrice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReplrTheme.Color.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ReplrTheme.Radius.sm, style: .continuous)
                            .fill(ReplrTheme.Color.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(ReplrTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReplrTheme.Radius.md, style: .continuous)
                .strokeBorder(ReplrTheme.Color.glassBorder, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Credits/CreditPacksView.swift"
git commit -m "feat: add CreditPacksView — 4 consumable pack cards, balance chip, restore"
```

---

## Task 11: iOS — Create ModelPickerView.swift (dev only)

**Files:**
- Create: `Replr/Replr/Features/Settings/ModelPickerView.swift`

- [ ] **Step 1: Write ModelPickerView**

```swift
import SwiftUI

/// Developer-only view. Not accessible from normal navigation.
/// Reached via long-press on version label in SettingsView.
struct ModelPickerView: View {
    @State private var selectedModelID = AppGroupService.shared.selectedModel
    @State private var devMode = AppGroupService.shared.devMode
    @StateObject private var credits = CreditsManager.shared

    var body: some View {
        List {
            Section {
                Toggle("Dev Mode (∞ credits, no deduction)", isOn: $devMode)
                    .tint(ReplrTheme.Color.accent)
                    .onChange(of: devMode) { value in
                        AppGroupService.shared.devMode = value
                        credits.refreshBalance()
                    }
            } header: {
                Text("Testing")
            } footer: {
                Text("When on: balance shows ∞, credits are never deducted. Off by default for all users.")
                    .font(.caption)
            }

            Section("Model") {
                ForEach(ReplrModel.allCases) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(ReplrTheme.Color.textPrimary)
                            Text("\(model.creditsPerRequest) credit\(model.creditsPerRequest == 1 ? "" : "s") / reply · \(model.apiModelID)")
                                .font(.system(size: 11))
                                .foregroundStyle(ReplrTheme.Color.textSecondary)
                        }
                        Spacer()
                        if selectedModelID == model.apiModelID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(ReplrTheme.Color.accent)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModelID = model.apiModelID
                        AppGroupService.shared.selectedModel = model.apiModelID
                    }
                }
            }

            Section("Current Balance") {
                HStack {
                    Text("Credits")
                    Spacer()
                    Text(credits.balanceDisplay)
                        .foregroundStyle(ReplrTheme.Color.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("Dev: Model Picker")
        .background(ReplrTheme.Color.bg.ignoresSafeArea())
        .onAppear {
            selectedModelID = AppGroupService.shared.selectedModel
            devMode = AppGroupService.shared.devMode
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add "Replr/Replr/Features/Settings/ModelPickerView.swift"
git commit -m "feat: add ModelPickerView — dev-only model selector with dev mode toggle"
```

---

## Task 12: iOS — Update GenerateReplyIntent.swift

**Files:**
- Modify: `Replr/Replr/Intents/GenerateReplyIntent.swift`

Replace the entire trial gate block and related logic:

- [ ] **Step 1: Replace trial gate with credit gate**

Find the current trial gate block (lines ~24–32):
```swift
// Trial gate
let isPremium = await SubscriptionManager.shared.isPremium
let trialUsed = AppGroupService.shared.trialUsedCount
guard isPremium || trialUsed < 10 else {
    NSLog("[Replr][Intent] trial exhausted — requesting paywall")
    AppGroupService.shared.paywallRequested = true
    AppGroupService.shared.saveError("trial_exhausted")
    return .result()
}
```

Replace with:
```swift
// Credit gate
let balance = AppGroupService.shared.effectiveCreditBalance
let required = AppGroupService.shared.devMode ? 0
    : CreditsManager.shared.creditsRequired(for: AppGroupService.shared.selectedModel)
guard balance >= required else {
    NSLog("[Replr][Intent] insufficient credits (%d required, %d available)", required, balance)
    AppGroupService.shared.saveError("insufficient_credits")
    return .result()
}
```

- [ ] **Step 2: Remove transactionId read and old isPremium check**

Find and remove:
```swift
let txID = UserDefaults(suiteName: Constants.appGroupID)?.string(forKey: Constants.transactionIDKey)
```
And remove `transactionId: txID` from the `generateReplies` call (already done in Task 8).

- [ ] **Step 3: Add credit deduction on success**

Find (in the success path, before `AppGroupService.shared.isGenerating = false`):
```swift
if !isPremium { AppGroupService.shared.trialUsedCount += 1 }
AppGroupService.shared.isGenerating = false
```

Replace with:
```swift
CreditsManager.shared.deduct(required)
AppGroupService.shared.isGenerating = false
```

- [ ] **Step 4: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

```bash
git add "Replr/Replr/Intents/GenerateReplyIntent.swift"
git commit -m "feat: replace trial gate with credit gate in GenerateReplyIntent"
```

---

## Task 13: iOS — Update KeyboardView.swift (credit counter)

**Files:**
- Modify: `ReplrKeyboard/Views/KeyboardView.swift`

- [ ] **Step 1: Replace trialRemaining with creditDisplay in KeyboardModel**

Find the `trialRemaining` computed property:
```swift
var trialRemaining: Int? {
    let txID = UserDefaults(suiteName: Constants.appGroupID)?
        .string(forKey: Constants.transactionIDKey)
    guard txID == nil else { return nil }
    return max(0, 10 - AppGroupService.shared.trialUsedCount)
}
```

Replace with:
```swift
/// Returns nil when dev mode (shows ∞ badge).
/// Returns the effective credit balance for display in the header.
var creditDisplay: CreditDisplay {
    if AppGroupService.shared.devMode { return .unlimited }
    let balance = AppGroupService.shared.effectiveCreditBalance
    return .count(balance)
}

enum CreditDisplay: Equatable {
    case unlimited
    case count(Int)
}
```

- [ ] **Step 2: Update the trial gate in generateEmailReply**

Find:
```swift
let remaining = trialRemaining ?? Int.max
guard remaining > 0 else {
    AppGroupService.shared.paywallRequested = true
    withAnimation(.easeInOut(duration: 0.2)) { state = .paywall }
    return
}
```

Replace with:
```swift
let balance = AppGroupService.shared.effectiveCreditBalance
let required = AppGroupService.shared.devMode ? 0
    : (ReplrModel(apiID: AppGroupService.shared.selectedModel)?.creditsPerRequest ?? 1)
guard balance >= required else {
    withAnimation(.easeInOut(duration: 0.2)) { state = .paywall }
    return
}
```

- [ ] **Step 3: Remove trial increment in generateEmailReply success path**

Find:
```swift
if trialRemaining != nil { AppGroupService.shared.trialUsedCount += 1 }
AppGroupService.shared.appendCaptureSession(session)
```

Replace with:
```swift
if !AppGroupService.shared.devMode {
    AppGroupService.shared.creditBalance -= required
}
AppGroupService.shared.appendCaptureSession(session)
```

- [ ] **Step 4: Update KeyboardHeader to show credit badge**

Find:
```swift
if let remaining = model.trialRemaining, remaining <= 3 {
    TrialCounterBadge(remaining: remaining)
} else {
    ReplrMark(size: 16)
        .opacity(isSegmentedDisabled ? 0.4 : 1.0)
}
```

Replace with:
```swift
switch model.creditDisplay {
case .unlimited:
    Text("∞")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(ReplrTheme.Color.accent)
case .count(let n) where n <= 20:
    CreditCounterBadge(count: n)
case .count:
    ReplrMark(size: 16)
        .opacity(isSegmentedDisabled ? 0.4 : 1.0)
}
```

- [ ] **Step 5: Replace TrialCounterBadge with CreditCounterBadge**

Find the `struct TrialCounterBadge` and replace with:

```swift
// MARK: - Credit Counter Badge

struct CreditCounterBadge: View {
    let count: Int

    private var color: Color {
        if count <= 3 { return ReplrTheme.Color.danger }
        if count <= 10 { return Color(red: 0.85, green: 0.60, blue: 0.10) }  // amber
        return ReplrTheme.Color.textSecondary
    }

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}
```

- [ ] **Step 6: Build to confirm**

⌘B. Fix any remaining references to `trialRemaining` or `TrialCounterBadge`. Expected: Build Succeeded.

- [ ] **Step 7: Commit**

```bash
git add ReplrKeyboard/Views/KeyboardView.swift
git commit -m "feat: replace trial counter with credit counter in keyboard, dev mode ∞ badge"
```

---

## Task 14: iOS — Update KeyboardViewController.swift

**Files:**
- Modify: `ReplrKeyboard/KeyboardViewController.swift`

- [ ] **Step 1: Update paywall detection in startCapturePoll**

Find:
```swift
if AppGroupService.shared.paywallRequested {
    await MainActor.run {
        withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .paywall }
    }
} else if AppGroupService.shared.switchKeyboardRequested {
```

Replace with:
```swift
if AppGroupService.shared.effectiveCreditBalance == 0 {
    await MainActor.run {
        withAnimation(.easeInOut(duration: 0.2)) { self.model.state = .paywall }
    }
} else if AppGroupService.shared.switchKeyboardRequested {
```

- [ ] **Step 2: Update viewWillAppear paywall check**

Find:
```swift
if AppGroupService.shared.paywallRequested || AppGroupService.shared.trialExhausted {
    let txID = UserDefaults(suiteName: Constants.appGroupID)?
        .string(forKey: Constants.transactionIDKey)
    if txID == nil {
        model.state = .paywall
    }
}
```

Replace with:
```swift
if AppGroupService.shared.effectiveCreditBalance == 0 {
    model.state = .paywall
}
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add ReplrKeyboard/KeyboardViewController.swift
git commit -m "feat: keyboard paywall triggers on creditBalance == 0, not paywallRequested"
```

---

## Task 15: iOS — Update ReplrApp.swift

**Files:**
- Modify: `Replr/Replr/App/ReplrApp.swift`

- [ ] **Step 1: Replace showPaywall trigger to use credit balance**

Find the `.onChange(of: scenePhase)` block:
```swift
.onChange(of: scenePhase) { phase in
    guard phase == .active else { return }
    AppGroupService.shared.synchronize()
    if AppGroupService.shared.paywallRequested {
        let txID = UserDefaults(suiteName: Constants.appGroupID)?
            .string(forKey: Constants.transactionIDKey)
        if txID == nil { showPaywall = true }
    }
}
```

Replace with:
```swift
.onChange(of: scenePhase) { phase in
    guard phase == .active else { return }
    AppGroupService.shared.synchronize()
    CreditsManager.shared.refreshBalance()
    if AppGroupService.shared.effectiveCreditBalance == 0 {
        showPaywall = true
    }
}
```

- [ ] **Step 2: Update fullScreenCover to show CreditPacksView**

Find:
```swift
.fullScreenCover(isPresented: $showPaywall) {
    NavigationStack {
        PaywallView(showCloseButton: true)
            .onDisappear {
                AppGroupService.shared.paywallRequested = false
            }
    }
}
```

Replace with:
```swift
.fullScreenCover(isPresented: $showPaywall) {
    NavigationStack {
        CreditPacksView(showCloseButton: true)
    }
}
```

- [ ] **Step 3: Remove SubscriptionManager task in ContentView**

Find in `ContentView.body`:
```swift
.task {
    let txID = await SubscriptionManager.shared.currentTransactionID()
    UserDefaults(suiteName: Constants.appGroupID)?.set(txID, forKey: "transaction_id")
}
```

Replace with:
```swift
.task {
    await CreditsManager.shared.load()
}
```

- [ ] **Step 4: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

```bash
git add "Replr/Replr/App/ReplrApp.swift"
git commit -m "feat: ReplrApp uses CreditsManager, shows CreditPacksView when balance is 0"
```

---

## Task 16: iOS — Update SettingsView.swift

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Replace PaywallView link with CreditPacksView**

Find:
```swift
NavigationLink(destination: PaywallView()) {
```

Replace with:
```swift
NavigationLink(destination: CreditPacksView()) {
```

- [ ] **Step 2: Add long-press ModelPickerView trigger on version label**

Find the app version text in SettingsView (it will be something like `Text("Version X.X.X")` or similar). Add a `NavigationLink` state and long-press:

Add at the top of `SettingsView`:
```swift
@State private var showModelPicker = false
```

Find the version label and wrap or add:
```swift
NavigationLink(destination: ModelPickerView(), isActive: $showModelPicker) {
    EmptyView()
}

// On the version Text, add:
.onLongPressGesture(minimumDuration: 1.5) {
    showModelPicker = true
}
```

If there is no version label, add one at the bottom of the settings list:
```swift
Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
    .font(.system(size: 12))
    .foregroundStyle(ReplrTheme.Color.textTertiary)
    .frame(maxWidth: .infinity, alignment: .center)
    .listRowBackground(Color.clear)
    .onLongPressGesture(minimumDuration: 1.5) {
        showModelPicker = true
    }
```

- [ ] **Step 3: Build to confirm**

⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add "Replr/Replr/Features/Settings/SettingsView.swift"
git commit -m "feat: SettingsView links to CreditPacksView, long-press version → ModelPickerView"
```

---

## Task 17: iOS — Delete SubscriptionManager and PaywallView

**Files:**
- Delete: `Replr/Replr/Subscription/SubscriptionManager.swift`
- Delete: `Replr/Replr/Subscription/PaywallView.swift`

- [ ] **Step 1: Delete the files**

```bash
rm "Replr/Replr/Subscription/SubscriptionManager.swift"
rm "Replr/Replr/Subscription/PaywallView.swift"
```

- [ ] **Step 2: Build to confirm no remaining references**

⌘B. If any "cannot find type 'SubscriptionManager'" or "cannot find type 'PaywallView'" errors appear, search the project and replace with `CreditsManager` or `CreditPacksView` respectively.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove SubscriptionManager and PaywallView — replaced by CreditsManager + CreditPacksView"
```

---

## Task 18: App Store Connect — Add consumable products

Manual step — no code.

- [ ] **Step 1:** Log in to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
- [ ] **Step 2:** Navigate to your app → In-App Purchases → (+) Create
- [ ] **Step 3:** Create 4 Consumable products:

| Display Name | Product ID | Price |
|---|---|---|
| 100 Credits | `Theory-of-Web.Replr.credits.100` | $1.99 (Tier 2) |
| 300 Credits | `Theory-of-Web.Replr.credits.300` | $4.99 (Tier 5) |
| 750 Credits | `Theory-of-Web.Replr.credits.750` | $9.99 (Tier 10) |
| 2500 Credits | `Theory-of-Web.Replr.credits.2500` | $24.99 (Tier 25) |

- [ ] **Step 4:** Archive/remove the 2 auto-renewable subscription products

---

## Self-Review

**Spec coverage check:**
- ✅ 4 model IDs in backend — Tasks 1-3
- ✅ Remove tier/transactionId from backend — Tasks 2-3
- ✅ Always 5 replies — Task 2
- ✅ JPEG compression — Task 8
- ✅ `creditBalanceKey`, `selectedModelKey`, `devModeKey`, `creditsMigratedKey` — Task 5
- ✅ `creditBalance`, `selectedModel`, `devMode`, `effectiveCreditBalance` — Task 6
- ✅ `ReplrModel` enum with 4 models, credits, apiID — Task 7
- ✅ `CreditsManager` — StoreKit consumables, migration, deduct, devMode bypass — Task 9
- ✅ `CreditPacksView` — 4 packs, balance, restore — Task 10
- ✅ `ModelPickerView` — dev-only, dev mode toggle, model list — Task 11
- ✅ `GenerateReplyIntent` credit gate — Task 12
- ✅ Keyboard credit counter (replaces trial), ∞ in dev mode — Task 13
- ✅ `KeyboardViewController` paywall on `creditBalance == 0` — Task 14
- ✅ `ReplrApp` uses `CreditsManager`, `CreditPacksView` — Task 15
- ✅ `SettingsView` long-press → `ModelPickerView` — Task 16
- ✅ Delete `SubscriptionManager`, `PaywallView` — Task 17
- ✅ App Store Connect products — Task 18
- ✅ Migration from trial/subscription — Task 9 (`migrateIfNeeded`)

**Type consistency:**
- `AppGroupService.shared.effectiveCreditBalance` — defined Task 6, used Tasks 12, 13, 14, 15 ✓
- `CreditsManager.shared.deduct(_:)` — defined Task 9, called Task 12 ✓
- `ReplrModel(apiID:)` — defined Task 7, used Task 13 ✓
- `CreditDisplay` enum — defined Task 13 (inside `KeyboardModel`) ✓
- `CreditCounterBadge(count:)` — defined Task 13, used in `KeyboardHeader` switch ✓
- `CreditsManager.shared.creditsRequired(for:)` — defined Task 9, used Task 12 ✓
