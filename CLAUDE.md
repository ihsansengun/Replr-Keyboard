# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Design system — read before any UI work

**When creating or modifying ANY UI, read and follow [`DESIGN.md`](DESIGN.md) first.**
It is the AI-facing design spec — tokens, components, and do's/don'ts, summarizing
`Shared/ReplrTheme.swift`. Never hardcode colors, fonts, radii, or spacing in views;
always use `ReplrTheme.*`. Design and verify both dark **and** light.

## Project overview

Replr is an iOS app that generates AI-powered reply suggestions from chat screenshots. It has two main components:

- **iOS app + keyboard extension** (`Replr/`) — Xcode project with companion app and custom keyboard extension
- **Backend** (`backend/`) — Cloudflare Worker (Hono + TypeScript) that calls Gemini/Claude/GPT/Grok and returns reply suggestions

## Backend commands

```bash
cd backend
npm run dev       # local Wrangler dev server
npm test          # run all tests (Vitest)
npm run typecheck # TypeScript check
npm run deploy    # deploy to Cloudflare Workers — ONLY when explicitly asked
```

Run a single test file:
```bash
cd backend && npm test -- tests/reply.test.ts
```

D1 migrations live in `backend/migrations/`. Apply locally with
`npx wrangler d1 migrations apply replr-db --local`; remote apply is a deploy-day
step, never done unprompted.

## iOS build

Open `Replr/Replr.xcodeproj` in Xcode. The project has two app targets (+ test targets):

| Target | Role |
|---|---|
| `Replr` | Companion app (SwiftUI, onboarding, tones, memory, settings, credits) |
| `ReplrKeyboard` | Custom keyboard extension (UIInputViewController + SwiftUI) |

All targets share `Shared/` via the App Group `group.com.ihsan.replr`.
The app folder (`Replr/Replr/`) is a synchronized group — new files are picked up
automatically. The keyboard's groups reference `../ReplrKeyboard/` and `../Shared/`
explicitly — **a `Shared/` helper used by several targets must live in a file that
is a member of all of them** (e.g. `AppGroupService.swift`).

Build gate:
```bash
cd Replr && xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
```
Run tests from Xcode: ⌘U (scheme `ReplrTests`). SourceKit errors like "No such
module 'UIKit'" or "Cannot find 'AppGroupService'" are false positives — xcodebuild
is the source of truth.

## Architecture

### Cross-process communication

All data between the companion app, keyboard extension, and intents flows through the App Group via `AppGroupService.shared` (`Shared/AppGroupService.swift`). It uses:
- **UserDefaults** (fast) for replies, errors, flags, tones, contacts, sessions, credits
- **Files** in the container for screenshots (`screenshot.png`, deleted after ~1 h by the app) and cross-process flags that must not cache stalely (`full_access_granted`)

`Constants.swift` has all App Group keys and the backend URL.

### Modes

The keyboard has three modes (`KeyboardInputMode`): **Chat**, **Dating**, **Email**.
The selection persists to the App Group (`selected_mode`) so intents use the
matching prompt family. Dating reuses the chat capture flow but sends
`mode: "dating"`, which selects a fully separate backend prompt family
(`DATING_IDENTITY`/`DATING_DECISIONS` in `llm.ts`): the AI classifies the
screenshot (profile → openers / empty chat → pick-up lines / ongoing → escalating
replies) and reports the branch via a `CONTEXT:` output line (`contextType` in
the response — no client UI in v1). Dating has its own tone set
(`Tone.datingToneNames`, 11 dating-only + 4 shared; default **Tease**) and
**always** uses match memory, regardless of the global Memory toggle.
Spec: `docs/superpowers/specs/2026-06-10-dating-mode-design.md`.

### Reply generation — two paths

**Intent path (Back Tap / Shortcuts):** `GenerateReplyIntent` or `QuickReplyIntent`
runs in the companion-app process, calls `ReplyService.shared.generateReplies()`
(POST `https://api.replr.app/reply`), writes results to the App Group, and the
keyboard's `startCapturePoll()` (250 ms loop in `KeyboardViewController`) picks
them up. The poll also watches Photos for new screenshots and mirrors
`isGenerating`/error/paywall state.

**In-keyboard path (screenshot chip, email mode, Regenerate):** `KeyboardModel`
calls `ReplyService` directly from the keyboard process (requires Full Access for
network). The old "never call async APIs from the keyboard" rule applies only to
keeping the Back Tap flow in the intent process — the keyboard does make its own
network calls on these paths.

Backend flow for both: `routes/reply.ts` → access gate (auth flag + KV rate limit)
→ optional server-side credit charge → `services/llm.ts` → `parseLlmOutput()`
extracts `CONTACT:`, `SUMMARY:`, and numbered replies.

### Keyboard state machine

`KeyboardState` enum (`ReplrKeyboard/Views/KeyboardView.swift`):

```
.idle / .loading / .replies([String]) / .error(String)
.disambiguate(name:candidates:)   (multiple contacts share a name)
.paywall                          (credits exhausted)
```

Collapse is a separate `isCollapsed` flag (capture strip), and `isCaptureMode`
shrinks the keyboard to 0 px during a capture handoff. `KeyboardModel`
(`@MainActor ObservableObject`) holds state and exposes callbacks to
`KeyboardViewController`, which wires them to the text document proxy.
Heights are set per state in `KeyboardViewController`; the replies panel reports
its measured natural height via `onContentHeightChanged` (clamped 280–400) —
see `docs/HANDOFF.md` §1 before touching this.

### Memory / contacts

Each successful capture creates a `CaptureSession` with `llmSummary` and
`contactID`. `AppGroupService.recentSummaries(forContactID:limit:)` feeds past
summaries to the LLM as `previousContext`. **Every fresh capture clears
`currentContactID` first** (all four generation sites) so a new chat is never
seasoned with the previous contact's memory; memory re-enters via Regenerate
after `resolveContact` identifies the contact from the LLM's `CONTACT:` line.

### Credits (monetization)

Consumable credit packs (StoreKit 2). The model's cost in credits is defined in
the backend catalog (`backend/src/services/models.ts`), served via `GET /config`,
and cached in the App Group (`remoteModelCatalog`) with a baked-in fallback in
`AppGroupService.creditsRequired`.

- **Server-authoritative when signed in:** the app adopts the local balance once
  via `POST /credits/migrate`, purchases are granted by `POST /credits/redeem`
  (StoreKit JWS verified against a pinned Apple root, deduped by transactionId),
  and `/reply` charges atomically server-side (402 → paywall; refund on LLM
  failure). Responses carry `creditsRemaining`, which all generation sites write
  back to the App Group.
- **Legacy/offline fallback:** local balance in App Group UserDefaults, deducted
  client-side. `CreditsManager` replays `Transaction.unfinished` and listens to
  `Transaction.updates` so interrupted purchases always grant.
- **Dev mode** (`devMode`): ∞ credits, no deduction, model switcher in the
  keyboard header. Server-side `users.is_dev` additionally exempts the dev
  account from ledger charges.
- **Paywall A/B**: `GET /paywall` (authed) returns the user's variant —
  products/order/badge/headline — from `ACTIVE_PAYWALL_EXPERIMENT`
  (`backend/src/services/paywall.ts`; deterministic hash, no storage).
  The app caches it (`remotePaywallConfig`) and `CreditPacksView` renders it;
  impressions and purchases land in D1 `paywall_events` with the variant
  recomputed server-side. Runbook: `docs/HANDOFF.md`.

### Backend structure

```
backend/src/
  index.ts            # Hono app, mounts routes
  middleware/
    session.ts        # Bearer token → authenticatedUserID (non-blocking)
  routes/
    reply.ts          # POST /reply — gate, charge, generate, refund
    auth.ts           # POST /auth/apple — Sign in with Apple → session token (D1)
    credits.ts        # GET /, POST /migrate, POST /redeem (all require session)
    config.ts         # GET /config — shortcut URL + model catalog
    health.ts         # GET /health
  services/
    llm.ts            # LLM calls (4 providers), prompt construction, parsing, PRICING
    models.ts         # MODEL_CATALOG (single model registry), CREDIT_PACKS
    credits.ts        # D1 ledger: getBalance / grant (deduped) / trySpend (atomic)
    appstore.ts       # StoreKit JWS chain verification (pinned Apple Root CA G3)
    rateLimit.ts      # KV daily limiter (user:<id> / ip:<addr> keys)
    auth.ts           # Apple identity-token validation (JWKS)
    tones.ts          # Tone library: temperature + few-shot examples per tone
  types/index.ts      # Env bindings, shared types
backend/migrations/   # D1 schema (users/sessions, credits/credit_ledger)
```

Rollout flags in `wrangler.toml`: `REQUIRE_AUTH` (flip to "true" to reject
anonymous clients), `ANON_DAILY_LIMIT` (per-IP), `MANAGED_DAILY_LIMIT` (circuit
breaker for credit-metered users — credits are their real meter),
`ALLOW_SANDBOX_TRANSACTIONS` (set "false" at public launch). See
`docs/HANDOFF.md` for the deploy-day runbook.

The LLM prompt always outputs: `CONTACT: …`, `SUMMARY: …`, then numbered replies.
`parseLlmOutput()` in `llm.ts` parses this format — keep it in sync if you change
the prompt format.

### Adding a model

Add it to `backend/src/services/models.ts` (catalog → validity + credit cost +
/config), `types/index.ts` `Model` union, `resolveModel()` + `PRICING` in
`llm.ts` — then app-side to `ReplrModel.swift`, keyboard `DevModelOption.all`,
and the fallback tables in `AppGroupService` (`creditsRequired`,
`selectedModelShortLabel`). The App Group catalog cache means costs/labels
update without an app release, but the app enums gate which models users can pick.

## Key design constraints

- The keyboard extension and companion app are separate processes. The Back Tap
  flow's heavy work runs in the intent (companion process); the keyboard's own
  generation paths call the network directly and need Full Access.
- `AppGroupService` uses `defaults.synchronize()` explicitly because extensions
  and the host app have separate UserDefaults caches.
- Credit deduction: always prefer the server's `creditsRemaining` (authoritative)
  over local arithmetic; the local path is the offline/legacy fallback only.
- iOS keyboard extensions cannot use intrinsic sizing — heights are managed in
  `KeyboardViewController` (state-based constants + measured replies height).
- Never push / merge / deploy / apply remote D1 migrations without an explicit ask.
