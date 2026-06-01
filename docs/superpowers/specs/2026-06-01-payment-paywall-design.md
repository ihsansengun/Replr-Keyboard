# Payment & Paywall Design

**Date:** 2026-06-01
**Status:** Approved

---

## Overview

Replr uses a trial-first monetisation model: users get 10 free requests with no payment friction during onboarding, then hit a paywall when the trial is exhausted. There is no ongoing free tier — non-converting users cost nothing after their trial is used.

---

## Monetisation Model

### Tiers

| | Trial | Pro Monthly | Pro Annual |
|---|---|---|---|
| Price | Free | $14.99/month | $99.99/year |
| Requests | 10 total (one-time) | 50/day | 50/day |
| Replies per generation | 3 | 5 | 5 |
| Scroll capture | No | Yes | Yes |
| Try Again | Yes (counts toward 10) | Yes | Yes |
| LLM model | Claude Sonnet 4.6 | Claude Sonnet 4.6 | Claude Sonnet 4.6 |
| Paywall trigger | After 10 used | — | — |

### Unit Economics (per paying user/month, after all deductions)

| Plan | After Apple (−30%) | After LLM (~$1.20) | After tax (~30%) | Net/month |
|---|---|---|---|---|
| Monthly $14.99 | $10.49 | $9.29 | **$6.50** | $6.50 |
| Annual $99.99 | $69.99/yr | $55.59/yr | **$38.91/yr = $3.24/mo** | $3.24 |
| Blended (60% monthly / 40% annual) | — | — | — | **~$5.20** |

### Profit at Scale (20% conversion, blended)

| Total users | Paying | Monthly profit |
|---|---|---|
| 500 | 100 | ~$500 |
| 1,000 | 200 | ~$1,020 |
| 2,000 | 400 | ~$2,060 |
| 5,000 | 1,000 | ~$5,180 |
| 10,000 | 2,000 | ~$10,380 |

### LLM Cost Reference

| Request type | Cost (Claude Sonnet 4.6) |
|---|---|
| Single screenshot, 3 replies | ~$0.011 |
| Single screenshot, 5 replies | ~$0.013 |
| Scroll capture, 6 frames, 5 replies | ~$0.037 |
| Trial acquisition (10 requests) | ~$0.11 one-time per user |

Image tokens cap at ~1,568 tokens for Sonnet 4.6 regardless of screenshot size.

---

## Trial System

### Storage
Two keys written to App Group UserDefaults (`group.com.ihsan.replr`):

```
replr.trial.usedCount    Int    0–10, incremented on each successful generate
replr.trial.exhausted    Bool   true when usedCount >= 10
```

### Enforcement
Client-side only. No backend trial tracking. The type of user who reinstalls to reset 10 free requests is not the target customer. Enforcement point is `GenerateReplyIntent.perform()`.

### Gate logic (pseudocode)
```swift
func perform() async throws -> some IntentResult {
    let isPremium = await SubscriptionManager.shared.isPremium
    let trialUsed = AppGroupService.shared.trialUsedCount

    guard isPremium || trialUsed < 10 else {
        AppGroupService.shared.paywallRequested = true
        throw ReplrError.trialExhausted
    }

    // proceed with generation
    if !isPremium {
        AppGroupService.shared.trialUsedCount += 1
    }
    // ... rest of generate flow
}
```

### Trial counter UI (keyboard)
Show remaining count only when ≤ 3 requests left. Never show above 3 — avoid priming users to ration early.

```
3 remaining → amber text in ReplrStrip right side: "3 left"
2 remaining → "2 left"
1 remaining → "1 left" (slightly more prominent)
0            → trigger .paywall keyboard state
```

---

## Payment Screens

### StoreKit 2 Products

| Product | ID | Price |
|---|---|---|
| Monthly | `Theory-of-Web.Replr.premium.monthly` | $14.99 |
| Annual | `Theory-of-Web.Replr.premium.yearly` | $99.99 |

Prices updated in App Store Connect. StoreKit fetches them dynamically — no hardcoding in the app.

**No third-party paywall SDK.** Native StoreKit 2 is sufficient for 2 products and 1 entitlement. RevenueCat to be reconsidered if product count exceeds 5 or A/B paywall testing is needed.

---

### Screen 1 — PaywallView (companion app, full screen)

Shown when:
- User opens companion app and `trial.exhausted == true`
- User taps "Open Replr" from keyboard paywall card
- User navigates to Settings → Premium (even if not exhausted, for early upgrades)

**Layout:**
```
┌─────────────────────────────┐
│                             │
│   ✦  Unlock Replr Pro       │  accent glow, display font
│   Reply smarter. Every time.│  secondary text
│                             │
│  ┌─────────┐ ┌───────────┐  │
│  │ Monthly │ │  Annual   │  │  Annual: teal border + glow (recommended)
│  │ $14.99  │ │  $99.99   │  │
│  │  /month │ │ Save 44%  │  │
│  └─────────┘ └───────────┘  │
│                             │
│  ✓  5 reply suggestions     │
│  ✓  Scroll capture          │
│  ✓  Unlimited daily use     │
│  ✓  Try Again anytime       │
│                             │
│  [  Continue with Annual  ] │  primary CTA, teal glow pill, full width
│                             │
│     Or continue monthly     │  secondary, plain text tap target
│                             │
│   Restore · Terms · Privacy │
└─────────────────────────────┘
```

**UX rules:**
- Annual is the default/primary CTA. Monthly is secondary (plain text, not a button).
- No dismiss button when arriving from trial exhaustion. User must choose a plan or close the app.
- When arriving from Settings (not exhaustion), show a close/back button.
- Prices always loaded from StoreKit, never hardcoded.
- Loading state while StoreKit fetches products: skeleton shimmer on plan cards.

---

### Screen 2 — Keyboard Paywall Card (`.paywall` state, 280px)

Triggered when keyboard polls App Group and finds `trial.exhausted == true` AND `isPremium == false`.

**Layout:**
```
┌─────────────────────────────┐
│  ReplrStrip (unchanged)     │
├─────────────────────────────┤
│                             │
│   Your 10 free replies      │
│   are up.                   │
│                             │
│   [  Unlock Pro in Replr  ] │  opens companion app via App Group flag
│                             │
│   $14.99/mo · $99.99/yr     │  secondary text, no interaction
│                             │
└─────────────────────────────┘
```

**"Unlock Pro in Replr" button behaviour:**
1. Writes `paywallRequested = true` to App Group
2. Attempts `extensionContext?.open(url:)` with `replr://paywall` URL scheme
3. If that fails (keyboard extension restriction): shows inline message "Open the Replr app to continue"
4. Companion app on next foreground: checks `paywallRequested`, auto-presents `PaywallView`

**Keyboard state machine addition:**
```
.idle → .paywall   (trial exhausted, not premium)
.paywall → .idle   (after purchase confirmed via App Group)
```

Height: 280px (same as idle/loading/error — no resize needed).

---

## App Group Keys (additions to Constants.swift)

```swift
static let trialUsedCount    = "replr.trial.usedCount"
static let trialExhausted    = "replr.trial.exhausted"
static let paywallRequested  = "replr.paywall.requested"
```

---

## Files Changed

| File | Change |
|---|---|
| `Constants.swift` | Add 3 trial + paywall App Group keys |
| `AppGroupService.swift` | Add `trialUsedCount`, `trialExhausted`, `paywallRequested` read/write |
| `GenerateReplyIntent.swift` | Add trial gate before API call, increment on success |
| `KeyboardView.swift` | Add `.paywall` case to `KeyboardState` |
| `KeyboardViewController.swift` | Handle `.paywall` height (280px, same as idle) |
| `KeyboardModel.swift` | Poll for `trialExhausted` alongside existing reply poll |
| `SubscriptionManager.swift` | Minor: write `paywallRequested = false` on purchase success |
| `ReplrApp.swift` | On foreground: check `paywallRequested`, present `PaywallView` if true |

**New files:**
| File | Purpose |
|---|---|
| `PaywallView.swift` | Full-screen paywall (replaces `SubscriptionView.swift`) |

`SubscriptionView.swift` is deleted and replaced by `PaywallView.swift`. The Settings tab links to `PaywallView` instead.

---

## Phase 2 — LLM Improvements (out of scope for this spec)

To be designed separately:
- **Fallback LLM chain:** Claude Sonnet 4.6 → GPT-4o → Claude Haiku 4.5 on error/timeout
- **Model selection per tier:** evaluate whether free trial uses a cheaper model
- **Grok integration:** if/when API becomes cost-competitive
- **Prompt caching:** cache system prompt to reduce input token costs ~10-15%

---

## Open Questions

1. **`extensionContext?.open(url:)` in keyboard extension** — needs verification during implementation. Fallback is App Group flag + manual instruction.
2. **App Store Connect pricing** — monthly and annual product prices need updating to $14.99 and $99.99 before submission.
3. **Trial reset policy** — currently no reset. If user deletes and reinstalls, trial resets (acceptable). No server-side enforcement planned.
