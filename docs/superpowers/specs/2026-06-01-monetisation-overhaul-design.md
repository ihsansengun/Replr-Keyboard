# Monetisation Overhaul: Credit Model + Multi-Model Testing

**Date:** 2026-06-01
**Status:** Approved

---

## Overview

Replace the existing subscription model with a pay-as-you-go credit system using StoreKit consumable in-app purchases. Expand model support from 2 (claude, gpt4o) to 4 testable models so the developer can compare reply quality in real usage before committing to a default. Credits deducted per request at a rate that reflects each model's LLM cost.

---

## Why This Design

- **Subscription loses money at high usage.** At 50 req/day, Sonnet subscription bleeds $12.51/month per user. Credits ensure you always profit regardless of usage intensity.
- **Single-model architecture preserved.** Each model sees the raw screenshot image directly — no two-step pipeline — to avoid context loss on shared media, reactions, visual relationship cues.
- **Multi-model testing.** Real-world side-by-side comparison in actual conversations is the only reliable way to evaluate reply quality. A model selector lets the developer make an evidence-based decision.

---

## Monetisation Model

### Credit Packs (StoreKit Consumable IAPs)

| Pack | Product ID | Price | Credits | $/credit |
|---|---|---|---|---|
| Starter | `Theory-of-Web.Replr.credits.100` | $1.99 | 100 | $0.020 |
| Standard | `Theory-of-Web.Replr.credits.300` | $4.99 | 300 | $0.017 |
| Value | `Theory-of-Web.Replr.credits.750` | $9.99 | 750 | $0.013 |
| Power | `Theory-of-Web.Replr.credits.2500` | $24.99 | 2,500 | $0.010 |

### Trial

10 free credits on first launch. No card required. Exhausted when `creditBalance` reaches 0. Same paywall trigger as before, now shows `CreditPacksView` instead of subscription screen.

### Credits Per Request by Model

| Model | Credits/request | LLM cost | Your profit/credit used |
|---|---|---|---|
| GPT-4.1-mini | 1 | $0.0016 | ~$0.009 |
| GPT-5.4-mini | 2 | $0.0036 | ~$0.008 |
| GPT-4.1 | 5 | $0.0078 | ~$0.006 |
| Claude Sonnet 4.6 | 8 | $0.013 | ~$0.005 |

All models see the raw screenshot image — single-call architecture, full visual context.

### Economics (GPT-4.1-mini default, average user 30 req/day)

- LLM cost/month: 900 × $0.0016 = **$1.44**
- User buys 750-credit pack ($9.99) every 25 days
- Revenue to you/month: ~$9.99 × 1.2 × 0.70 = **$8.39**
- **Profit/month: ~$6.95** (after tax ~$4.87)

---

## Model Lineup

### Supported Models (Backend)

The backend supports all 4 models for routing. End users never choose between them.

| Model ID | Display name | Provider | Vision | Credits/req |
|---|---|---|---|---|
| `gpt-4.1-mini` | GPT-4.1 Mini | OpenAI | ✅ | 1 |
| `gpt-5.4-mini` | GPT-5.4 Mini | OpenAI | ✅ | 2 |
| `gpt-4.1` | GPT-4.1 | OpenAI | ✅ | 3 |
| `claude-sonnet-4-6` | Claude Sonnet | Anthropic | ✅ | 3 |

### User-Facing Tiers (Post-Testing)

After developer testing is complete, offer at most **two** user-visible tiers:

| Tier | Model | Credits | Framing |
|---|---|---|---|
| **Standard** | Winner from testing (default: `gpt-4.1-mini`) | 1 | Fast, natural |
| **Enhanced** *(optional)* | Runner-up or Sonnet — only if quality difference is genuinely perceptible | 3 | Deeper context, better reads |

If testing shows GPT-4.1-mini is good enough on its own, Enhanced is not offered — one model, no choice, no confusion.

### Developer Testing Mode (Hidden)

The model picker is **not visible to end users**. It is accessed via a hidden trigger in Settings (e.g. long-press on the version number). Shows all 4 models. Switching model does not cost credits in dev mode (a `devMode: true` flag bypasses credit deduction). The developer uses this to compare reply quality in real conversations before deciding on the default.

The selected model is stored in App Group UserDefaults (`replr.credits.model`) so both the companion app and keyboard extension use the same value.

---

## Architecture

### Credit Storage (Client-Side)

Credits are tracked in App Group UserDefaults — no server account required. Same security model as the trial counter (client-side enforcement is acceptable; the type of user who would exploit this is not the target customer).

```
replr.credits.balance    Int    current credit balance (starts at 10)
replr.credits.model      String current selected model ID
```

### Credit Deduction Flow

```
User triggers generate
    ↓
GenerateReplyIntent / KeyboardModel checks:
  - creditBalance > 0?  No → show paywall
  - creditBalance >= creditsRequired(selectedModel)?  No → show paywall
    ↓
API call made with selectedModel
    ↓
On SUCCESS: deduct creditsRequired(selectedModel) from balance
On FAILURE: do not deduct (failed request doesn't cost the user)
```

### Backend Model Routing

The request body adds a `model` field supporting all 4 model IDs. Backend routes to the appropriate provider:

```typescript
// Standard routing
if (model.startsWith('gpt-')) → OpenAI client
if (model.startsWith('claude-')) → Anthropic client

// Model ID → API model string mapping
'gpt-4.1-mini'      → 'gpt-4.1-mini'
'gpt-5.4-mini'      → 'gpt-5.4-mini'  
'gpt-4.1'           → 'gpt-4.1'
'claude-sonnet-4-6' → 'claude-sonnet-4-6'
```

All models receive the same prompt structure. Output parsing (`parseLlmOutput`) is unchanged — all models use the same `CONTACT:` / `SUMMARY:` / numbered reply format.

### Rate Limiting

KV rate limiter is kept as a backend safety net against abuse, but the credit check on the client side is the primary gate. Free tier (10 credits) = old free tier semantics.

---

## Backend Changes

### `backend/src/types/index.ts`

Update `Model` type:
```typescript
export type Model = 'gpt-4.1-mini' | 'gpt-5.4-mini' | 'gpt-4.1' | 'claude-sonnet-4-6'
```

Remove `Tier` type (no longer needed).

### `backend/src/services/llm.ts`

- Replace `if (model === 'claude')` / `else` (GPT-4o) branching with a router that maps model IDs to provider + API model string
- Add `openAIModelId()` and `anthropicModelId()` helpers
- Remove `PREMIUM_REPLY_COUNT` / `tier` parameter — always generate 5 replies (reply count is no longer a tier differentiator)
- Keep `parseLlmOutput()`, `buildContextBlock()`, `buildReplyFormat()` unchanged

```typescript
function resolveModel(model: Model): { provider: 'openai' | 'anthropic', apiModel: string } {
  switch (model) {
    case 'gpt-4.1-mini':      return { provider: 'openai',    apiModel: 'gpt-4.1-mini' }
    case 'gpt-5.4-mini':      return { provider: 'openai',    apiModel: 'gpt-5.4-mini' }
    case 'gpt-4.1':           return { provider: 'openai',    apiModel: 'gpt-4.1' }
    case 'claude-sonnet-4-6': return { provider: 'anthropic', apiModel: 'claude-sonnet-4-6' }
  }
}
```

### `backend/src/routes/reply.ts`

- Remove `transactionId` / `tier` / rate limit premium bypass logic
- Validate `model` against the 4 known model IDs
- Remove `tier` from `generateReplies()` call
- Keep rate limit KV check for all users (soft abuse protection)
- All users get 5 replies (reply count no longer varies)

---

## iOS Changes

### New Files

**`Replr/Replr/Credits/CreditsManager.swift`**
- `@MainActor final class CreditsManager: ObservableObject`
- `@Published var balance: Int` — reads/writes App Group `replr.credits.balance`
- `@Published var selectedModel: ReplrModel` — reads/writes App Group `replr.credits.model`
- `@Published var products: [Product]` — StoreKit consumable products
- `func load() async` — fetches StoreKit products
- `func purchase(_ product: Product) async throws` — consumable IAP, adds credits to balance on success
- `func deduct(_ credits: Int)` — called after successful generation
- `func creditsRequired(for model: ReplrModel) -> Int` — returns 1/2/5/8

**`Replr/Replr/Credits/CreditPacksView.swift`**
- Full-screen purchase UI (replaces `PaywallView`)
- Shows 4 pack cards with credit count, price, price-per-credit
- "Best value" badge on 750-credit pack
- Shows current balance at top
- Restore purchases + Terms + Privacy footer
- `showCloseButton: Bool` param (same as PaywallView)

**`Replr/Replr/Credits/ReplrModel.swift`**
- `enum ReplrModel: String, CaseIterable`
- Cases: `gpt4_1mini`, `gpt5_4mini`, `gpt4_1`, `claudeSonnet4_6`
- `var displayName: String` — user-facing name
- `var creditsPerRequest: Int` — 1/2/5/8
- `var apiModelID: String` — sent to backend

### Modified Files

**`Shared/Constants.swift`**
Add:
```swift
static let creditBalanceKey  = "replr.credits.balance"
static let selectedModelKey  = "replr.credits.model"
static let creditsMigratedKey = "credits.migrated"
```
Keep `trialUsedCountKey` and `transactionIDKey` as read-only — needed by the one-time migration in `CreditsManager.migrateIfNeeded()`. Remove `trialExhaustedKey` and `paywallRequestedKey` — no longer used.

**`paywallRequested` replacement:** All existing code that reads/writes `paywallRequested` must be updated to use `creditBalance == 0` as the trigger condition. Specifically:
- `GenerateReplyIntent`: write `creditBalance = 0` is implicit (deduct until 0); set `AppGroupService.shared.paywallRequested` removed
- `KeyboardViewController.startCapturePoll()`: check `creditBalance == 0` instead of `paywallRequested`
- `KeyboardViewController.viewWillAppear`: check `creditBalance == 0`
- `ReplrApp.onChange(scenePhase)`: check `creditBalance == 0`
- `PaywallCardView.openPaywallInApp()`: remove `paywallRequested = true`

> **Migration note:** On first launch after update, if `trialUsedCountKey` is set, read remaining trial count (10 - usedCount) and write to `creditBalanceKey`. Then remove trial keys. If user had a valid StoreKit transaction (premium subscriber), write 1,000 credits as goodwill migration.

**`Shared/AppGroupService.swift`**
- Replace `trialUsedCount`, `trialExhausted`, `paywallRequested` with:
  ```swift
  var creditBalance: Int { get / set }
  var selectedModel: String { get / set }
  ```
- Keep pattern: computed var with `defaults.synchronize()`

**`Replr/Replr/Intents/GenerateReplyIntent.swift`**
- Remove `SubscriptionManager.shared.isPremium` check
- Remove `trialUsedCount` logic
- Add: check `AppGroupService.shared.creditBalance >= creditsRequired`
- If insufficient: write `paywallRequested = true`, return error
- On success: call `AppGroupService.shared.creditBalance -= creditsRequired`
- Pass `AppGroupService.shared.selectedModel` as `model` field in API request

**`Replr/Replr/App/ReplrApp.swift`**
- Replace `SubscriptionManager` with `CreditsManager`
- `.onChange(of: scenePhase)`: check `creditBalance == 0` instead of `paywallRequested`
- Auto-present `CreditPacksView` when balance hits 0

**`Replr/Replr/Features/Settings/SettingsView.swift`**
- Replace `NavigationLink(destination: PaywallView())` with `NavigationLink(destination: CreditPacksView())`
- No user-visible model row
- Hidden model picker accessible via long-press on version number label

**New: `Replr/Replr/Features/Settings/ModelPickerView.swift`** *(developer only)*
- Hidden view — not reachable from normal navigation
- List of 4 models with display name, API ID, credit cost badge, checkmark on selected
- "Dev Mode" toggle at top — when on, bypasses credit deduction for testing
- Tapping a model writes to `AppGroupService.shared.selectedModel`
- Accessible via long-press on app version label in Settings

**`ReplrKeyboard/Views/KeyboardView.swift`**
- `KeyboardModel.trialRemaining` → `creditBalance` (read from App Group)
- Counter in header: shows balance number instead of "X left" when ≤ 20 credits
- `PaywallCardView`: unchanged layout, "credits are up" text already appropriate

**`ReplrKeyboard/KeyboardViewController.swift`**
- `viewWillAppear`: check `creditBalance == 0` instead of `trialExhausted`

**`Replr/Replr/Subscription/PaywallView.swift`** — DELETE (replaced by `CreditPacksView`)
**`Replr/Replr/Subscription/SubscriptionManager.swift`** — DELETE (replaced by `CreditsManager`)

---

## App Store Connect Setup

1. Add 4 consumable in-app purchases:
   - `Theory-of-Web.Replr.credits.100` — $1.99
   - `Theory-of-Web.Replr.credits.300` — $4.99
   - `Theory-of-Web.Replr.credits.750` — $9.99
   - `Theory-of-Web.Replr.credits.2500` — $24.99
2. Remove or archive the 2 auto-renewable subscription products (monthly/annual)

---

## Migration (Existing Users)

On first launch after update, `CreditsManager.init()` runs a one-time migration:

```swift
func migrateIfNeeded() {
    guard !defaults.bool(forKey: "credits.migrated") else { return }
    
    // Trial users: convert remaining trial to credits
    let trialUsed = defaults.integer(forKey: Constants.trialUsedCountKey)
    let remaining = max(0, 10 - trialUsed)
    if remaining > 0 {
        creditBalance = remaining
    }
    
    // Premium subscribers: 1,000 goodwill credits
    if let txID = defaults.string(forKey: Constants.transactionIDKey), !txID.isEmpty {
        creditBalance += 1000
    }
    
    defaults.set(true, forKey: "credits.migrated")
    defaults.synchronize()
}
```

---

## Screenshot Payload Optimisation

**JPEG compression at capture time** — not at send time.

Compress the screenshot when `CaptureService` or `SampleHandler` saves it to the App Group container. By the time the user Back Taps and `GenerateReplyIntent` fires, the compressed image is already ready. Zero user-perceived latency.

```swift
// In CaptureService / SampleHandler, when saving screenshot to App Group:
let compressed = UIImage(data: rawPNGData)?
    .jpegData(compressionQuality: 0.82) ?? rawPNGData
try compressed.write(to: screenshotURL)
```

**Why:** iPhones capture screenshots as full-resolution PNG (~2MB). JPEG at 82% quality reduces this to ~350–400KB (5× smaller). Compression takes ~15–25ms on hardware (invisible to user). Upload savings: 250ms on WiFi, 640ms on 4G, 1,280ms on weak connections.

**Note:** This does not reduce image tokens (tokens are based on pixel dimensions, not file size). It purely improves upload speed and reduces API payload.

---

## Phase 2 (Out of Scope)

- Grok integration (pending API pricing confirmation)
- Gemini 2.5/3.5 Flash (pending pricing)
- Server-side credit validation for high-volume abuse prevention
- Credit gifting / referral programme

---

## Open Questions

1. **GPT-5.4-mini model ID** — verify exact API string with OpenAI docs before implementation (`gpt-5.4-mini` assumed)
2. **Scroll capture credit cost** — scroll uses multiple frames but is one generation. Recommend: same credit cost as single (1/2/5/8 depending on model) since it's one reply set, just with richer input.
3. **Low balance warning threshold** — keyboard counter shows balance when ≤ 20 credits. Is 20 the right threshold?
