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

### Supported Models

| Model ID | Display name | Provider | Vision | Credits/req |
|---|---|---|---|---|
| `gpt-4.1-mini` | GPT-4.1 Mini | OpenAI | ✅ | 1 |
| `gpt-5.4-mini` | GPT-5.4 Mini | OpenAI | ✅ | 2 |
| `gpt-4.1` | GPT-4.1 | OpenAI | ✅ | 5 |
| `claude-sonnet-4-6` | Claude Sonnet | Anthropic | ✅ | 8 |

### Model Picker (Settings → Model)

A developer/testing picker in Settings. Shows all 4 models with their credit cost per request. User switches model, uses keyboard normally in real conversations, observes reply quality difference. Default: `gpt-4.1-mini`.

The selected model is stored in App Group UserDefaults (`replr.model.selected`) so both the companion app and keyboard extension read the same value.

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
- Add new "Model" row: shows current model name → navigates to `ModelPickerView`

**New: `Replr/Replr/Features/Settings/ModelPickerView.swift`**
- List of 4 models with display name, credit cost badge, and checkmark on selected
- Tapping a model writes to `AppGroupService.shared.selectedModel`
- Subtitle on each: "1 credit/reply · $0.002 equivalent" etc.

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
