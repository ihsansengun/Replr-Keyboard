# UX Redesign — Handoff TODOs

**Date:** 2026-06-02
**For:** Next Claude session / next developer picking up the UX work
**Branch state:** `main` at commit `a1a5151` — reverted from a failed onboarding redesign attempt. Codebase is back to the pre-PR working state.

---

## Why this handoff exists

A previous session attempted a full onboarding redesign (11 states → 2 screens, deferred Back Tap setup, auto-collapse capture flow). The implementation got most of the way but the user found the resulting UX bad enough that we reverted the entire branch. They want a different tool / approach to drive the next attempt.

This document captures everything we learned along the way so the next attempt doesn't repeat our mistakes.

---

## The hard platform constraints (don't waste cycles rediscovering these)

### 1. No deep-linking past top-level Settings

Apple does **not** allow third-party apps to deep-link past the Settings root or the app's own Settings page. `UIApplication.openSettingsURLString` is the only public API. Confirmed via deep research with citations — see findings below.

The undocumented `prefs:root=` and `App-Prefs:root=` URL schemes:
- Are classified by Apple as **private API** (Apple DTS engineer Quinn "The Eskimo!" stated this verbatim on developer forums)
- Have triggered App Store rejections under Guideline 2.5.1 (multiple documented cases 2018–2024)
- Apple's rejection language explicitly threatens **developer account termination** for continued use
- Largely **stopped working on iOS 18** — sub-path syntax (`&path=`) is broken
- The specific Back Tap URL `prefs:root=ACCESSIBILITY&path=TOUCH_REACHABILITY_TITLE/Back%20Tap` documented in community lists is unverified on current iOS

**Source citations:**
- [Apple Developer Forums #691712](https://developer.apple.com/forums/thread/691712)
- [Apple Developer Forums #759900](https://developer.apple.com/forums/thread/759900) (iOS 18 breakage)
- [Apple Developer Forums #100471](https://developer.apple.com/forums/thread/100471) (rejection language)

### 2. The Shortcuts loophole (the one creative path)

Settings URL schemes **can** be launched from within a Shortcut via the "Open URLs" action (since iOS 13.1.2). Because Apple's Shortcuts app executes the URL — not your binary — your app carries no review-risk attribution. The user's iCloud-hosted shortcut is the place to embed any private URL.

**Caveat:** Even via this path, drilling deeper than the Accessibility root has been unreliable across iOS versions. Best case today: a Shortcut step that opens `prefs:root=ACCESSIBILITY` gets users one tap closer than the app could. Test empirically on iOS 17 and iOS 18 before relying on it.

### 3. Keyboard extension cannot call `extensionContext?.open()` reliably

It's silently ignored in many host apps (iMessage, Instagram, etc.). Don't design flows that depend on the keyboard opening the companion app via deep link. We tried this in the reverted PR and it didn't work.

### 4. IAPs in TestFlight require App Store Review approval

IAPs at "Ready to Submit" status do NOT load in TestFlight sandbox. To make them work in TestFlight:
1. Submit a binary to **App Store Review** with the IAPs attached
2. Apple approves them (~24h)
3. Only then do they become available to TestFlight testers

Local Xcode testing works via the `.storekit` file or sandbox directly — different code path. The user's products in App Store Connect are all "Ready to Submit" but unapproved.

---

## What was reverted from the failed PR (don't re-do these mistakes)

The reverted onboarding attempt tried:
- 2-screen onboarding (Welcome + combined Keyboard/FullAccess)
- Deferred Back Tap setup via a chip in the keyboard idle state
- Auto-collapse capture (`CollapseKeyboardIntent` setting a flag, keyboard polling for it)
- Removed the "Before your first reply" privacy modal
- Inline keyboard instructions: "Open the Replr app → tap Wire the trigger"

**Why it failed:**
- The deferred setup felt confusing — users finished onboarding without their core trigger configured
- The keyboard "Setup needed" chip tried to deep-link via `extensionContext?.open()` which doesn't work in most host apps
- Inline text instructions in the keyboard ("Open the Replr app...") felt like instructions, not product
- The auto-collapse worked but the overall UX wasn't worth the friction reduction
- The user (rightfully) judged the final result as worse than the original 11-state flow

**Lesson:** Don't repeat "split the setup into onboarding + deferred" as a structure. The next attempt needs to make all the setup feel like the product, in one place.

---

## What to keep from the research

These ideas survived the revert and are worth carrying into the next attempt:

1. **The Welcome screen privacy footnote already exists** and is sufficient. The mid-use modal can stay removed in the next design.
2. **The shortcut tone parameter is misleading** — `GenerateReplyIntent` should read `AppGroupService.shared.readSelectedTone()` rather than the shortcut parameter (which is hardcoded to "Friendly"). This is a clean win independent of the redesign — see "Quick wins" below.
3. **The auto-collapse mechanism is sound** — the issue wasn't the technical pattern, it was that it didn't justify the new onboarding around it. If the next design wants to use it, the implementation pattern works (CollapseKeyboardIntent → captureRequested flag → keyboard polls and collapses → ~500ms wait → screenshot).

---

## Concrete TODOs for the next session

### TODO 1: Onboarding redesign (the main work)

Use the brief at `docs/superpowers/handoffs/2026-06-02-gemini-redesign-brief.md` (also being created — see below). Drop the screenshots of the current UI into Gemini along with this brief.

**Key things the new design must solve:**

- The Back Tap setup is six levels deep into iOS Settings. There is no deep-link. The design must make the six-level dive feel confident and completable on the first try.
- Possible directions (let the design tool propose; don't prescribe):
  - Pre-recorded screen recording loop showing the exact path
  - Custom-illustrated stylized walkthrough of each Settings level
  - "We'll be waiting" return state that confirms success the moment the user comes back
  - Persistent guide that pre-loads visual aides the moment the user taps "Open Settings"
  - Celebration moment when Back Tap fires for the first time (we can detect this via `lastIntentFiredAt`)
- The bar: users complete this on the first try, feel competent doing it, remember it as the best setup flow they've used.

**Visual brief:** Premium, Apple-featured caliber. Unique icon set (not SF Symbols as identity). Unique UI components (custom tone selector, custom reply card, custom setup checklist). No AI-startup aesthetic (no purple gradients, no sparkles, no neural-network motifs).

### TODO 2: Move shortcut URL to backend

The iCloud Shortcuts URL is currently hardcoded in `Shared/Constants.swift`:

```swift
static let shortcutInstallURL = "https://www.icloud.com/shortcuts/7d03cee2dc4a437286c11fff5077cc80"
```

Move it server-side so the shortcut can be updated without an App Store release.

**Implementation:**

1. **Backend** (`backend/src/routes/config.ts`):
   - `GET /config` endpoint
   - Accepts optional `?appVersion=X.Y.Z` query param
   - Returns `{ "shortcutInstallURL": "...", "minSupportedAppVersion": "1.0", "shortcutVersion": "1.0" }`
   - Set `Cache-Control: public, max-age=3600` so Cloudflare edge serves it
   - Log requests with appVersion for tracing

2. **iOS** (`Shared/ConfigService.swift`, new file):
   - Fetches `/config` lazily — only when the URL is needed (e.g. user taps "Install Shortcut")
   - Caches the response in `AppGroupService` with a 24h TTL
   - Falls back to `Constants.fallbackShortcutInstallURL` (renamed from `shortcutInstallURL`) on network error
   - Returns `String` (not URL) — let the caller parse

3. **Call sites** (`Replr/Features/Onboarding/OnboardingView.swift`):
   - Replace `Constants.shortcutInstallURL` with `await ConfigService.shared.shortcutInstallURL`
   - Currently used in `InstallShortcutStep` (line ~395) and `BackTapSetupFullView`

Total work: ~half-day. Low risk.

### TODO 3: Fix the tone override bug

The shortcut hardcodes "Friendly" as the Tone parameter passed to `GenerateReplyIntent`. This means the user's selected tone in the keyboard is ignored.

**Fix in `Replr/Replr/Intents/GenerateReplyIntent.swift`:**

```swift
// Around line 44 in perform(), replace:
let context = AppGroupService.shared.readPendingContext()
NSLog("[Replr][Intent] Calling API: tone=%@, hasContext=%d", tone.rawValue, context != nil ? 1 : 0)
// ...
let result = try await ReplyService.shared.generateReplies(
    screenshot: image,
    tone: tone.tone,  // <-- this is the shortcut param, hardcoded to "Friendly"
    summary: context,
    previousContext: previousContext
)

// With:
let context = AppGroupService.shared.readPendingContext()
let effectiveTone = AppGroupService.shared.readSelectedTone()
NSLog("[Replr][Intent] Calling API: tone=%@ (shortcut param=%@), hasContext=%d",
      effectiveTone.name, tone.rawValue, context != nil ? 1 : 0)
// ...
let result = try await ReplyService.shared.generateReplies(
    screenshot: image,
    tone: effectiveTone,
    summary: context,
    previousContext: previousContext
)
```

Total work: 5 minutes. Should ship independently — not tied to the redesign.

### TODO 4: Credits starting balance + pack copy

Currently new users get 10 starting credits via the migration in `Replr/Replr/Credits/CreditsManager.swift`. Claude Sonnet costs 8 credits per capture. New users hit the paywall after 1 capture, which is too aggressive.

**Recommendations:**

1. **Bump starting credits to 40** (≈5 free captures). Update `migrateIfNeeded()`:
   ```swift
   let trialUsed = defaults.integer(forKey: Constants.trialUsedCountKey)
   let trialRemaining = max(0, 10 - trialUsed)
   let startingCredits = max(40, trialRemaining)
   AppGroupService.shared.creditBalance += startingCredits
   ```

2. **Fix pack copy** in `Replr/Replr/Credits/CreditPacksView.swift`. Currently says "1 credit = 1 reply suggestion" which is misleading (actually 8 credits for 3 suggestions). Change to: `"8 credits per capture · 3 replies each"` — or make dynamic from the current model's `creditsPerRequest`.

3. **Cost breakdown for reference** (Claude Sonnet, ~1845 input + 250 output tokens):
   - Per capture: ~$0.009–$0.013 actual API cost
   - Current pack margins (3–9x) are healthy — pricing doesn't need to change
   - The issue is only the starting credits + the misleading copy

Total work: 15 minutes. Should ship independently.

### TODO 5: IAP submission for TestFlight

For the public TestFlight link to work properly with purchases, the 4 IAPs need to be approved by Apple. Steps:

1. App Store Connect → your app → create new App Store version
2. Attach all 4 IAPs (`com.ihsan.replr.credits.100/300/750/2500`) to that version
3. Submit for App Store Review (can withdraw before they reject if not ready to ship publicly)
4. Wait ~24h for Apple to approve the IAPs
5. Once IAPs flip to "Approved", they will load in TestFlight automatically

Until this happens, TestFlight testers see the infinite-spinner state on the paywall.

### TODO 6: Re-evaluate the keyboard setup-state UX (post-redesign)

If the new onboarding from TODO 1 ships, the keyboard's idle state needs a parallel rethink. Right now there's no signal in the keyboard when Back Tap isn't yet configured. Options the new design should consider:

- A subtle "setup pending" indicator that doesn't shout
- No special state at all — trust the onboarding to land the trigger, treat all keyboard sessions as "ready"
- A one-time tooltip the first time the keyboard opens post-onboarding

Don't pre-decide this; let the visual brief from TODO 1 determine the right approach.

---

## File / state notes for the next session

**The codebase state:**
- HEAD: `a1a5151` (last commit before the failed PR)
- The original `BackTapStepView.swift` is back at `Replr/Replr/Features/Onboarding/BackTapStepView.swift`
- The original 5-step onboarding coordinator is in `OnboardingView.swift`
- All credits/storekit code is in the original pre-PR state
- The `.storekit` local file was overwritten during our work and I restored it as empty — the user can re-sync from App Store Connect via Xcode if they want it populated
- The user's Run scheme has StoreKit Configuration set to **None** (changed during debugging) — they may want to switch this back to `Replr.storekit` if they want local sandbox testing

**Two design references for the next session:**
- The full Gemini redesign brief (separate file: `docs/superpowers/handoffs/2026-06-02-gemini-redesign-brief.md` — see TODO below to create if not yet done)
- The current 30 production screenshots at `docs/design/screenshots/IMG_8535.PNG` through `IMG_8565.PNG` (the user took these on device)

**Untouched but maybe worth knowing:**
- The companion app's `replr://setup` deep link still routes to `BackTapSetupFullView` in `ReplrApp.swift` — this is the original single-step Back Tap instruction sheet
- `lastIntentFiredAt` in `AppGroupService` is reliably set by `GenerateReplyIntent.perform()` — use this as the "Back Tap is working" signal in any new design
- The Telegraph design system tokens are in `Shared/ReplrTheme.swift` — accent is `#17EAD9` teal in dark, `#008780` in light. Whatever the new design decides about color, the token file is the place to swap it.

---

## Suggested approach for the next session

1. Read this handoff doc + the Gemini redesign brief
2. Skim the deep-research findings on Settings deep-linking (don't re-research — the answer is final)
3. Quick wins first (TODOs 3, 4, 5) — these unblock the user and ship independently of the redesign
4. For the redesign itself (TODO 1), get the Gemini output, present it to the user for approval before any code, then write a fresh spec → plan → implement using the superpowers brainstorming/writing-plans/subagent-driven-development skills
5. Move the shortcut URL to the backend (TODO 2) at any point — easy, isolated, no design dependency

Don't try to implement the redesign without the user approving the visual direction first. The reverted PR's mistake was committing to an architecture (deferred Back Tap setup) before validating it was actually better than the original. Get visual mockups → user approval → then spec → then code.
