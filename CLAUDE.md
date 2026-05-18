# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Replr is an iOS app that generates AI-powered reply suggestions from chat screenshots. It has two main components:

- **iOS app + extensions** (`Replr/`) — Xcode project with companion app, custom keyboard extension, and screen broadcast extension
- **Backend** (`backend/`) — Cloudflare Worker (Hono + TypeScript) that calls Claude or GPT-4o and returns reply suggestions

## Backend commands

```bash
cd backend
npm run dev       # local Wrangler dev server
npm test          # run all tests (Vitest)
npm run typecheck # TypeScript check
npm run deploy    # deploy to Cloudflare Workers
```

Run a single test file:
```bash
cd backend && npm test -- tests/reply.test.ts
```

## iOS build

Open `Replr/Replr.xcodeproj` in Xcode. The project has four targets:

| Target | Role |
|---|---|
| `Replr` | Companion app (SwiftUI, onboarding, tones, memory, settings, subscription) |
| `ReplrKeyboard` | Custom keyboard extension (UIInputViewController + SwiftUI) |
| `ReplrBroadcast` | ReplayKit broadcast extension (screen capture) |
| `ReplrBroadcastSetupUI` | Setup UI for broadcast extension |

All targets share `Shared/` via the App Group `group.com.ihsan.replr`.

Run tests from Xcode: ⌘U (scheme `ReplrTests`).

## Architecture

### Cross-process communication

All data between the companion app, keyboard extension, intent, and broadcast extension flows through the App Group via `AppGroupService.shared` (`Shared/AppGroupService.swift`). It uses:
- **UserDefaults** (fast) for replies, errors, flags, tones, contacts, sessions
- **Files** in the container for screenshots (`screenshot.png`) and scroll frames (`scroll_frame_N.png`)

`Constants.swift` has all App Group keys and the backend URL.

### Reply generation flow

1. User triggers capture via Back Tap → `GenerateReplyIntent` (AppIntent in companion app), or via the Shortcuts app with screenshot, or via the broadcast extension
2. `GenerateReplyIntent.perform()` calls `ReplyService.shared.generateReplies()` which POSTs a base64 screenshot + tone + optional context/memory summaries to `https://api.replr.app/reply`
3. Backend (`backend/src/routes/reply.ts`) checks rate limit (KV), calls `generateReplies()` in `services/llm.ts` using Claude Sonnet 4-6 or GPT-4o
4. LLM output is parsed by `parseLlmOutput()`: extracts `CONTACT:`, `SUMMARY:`, and numbered replies
5. Results written to App Group via `AppGroupService.shared.saveReplies()`
6. Keyboard polls App Group every 1 second in `startCapturePoll()` and transitions to `.replies([String])` state when it finds new data

### Keyboard state machine

`KeyboardState` enum (`ReplrKeyboard/Views/KeyboardView.swift`) drives the entire keyboard UI:

```
.idle → .collapsed (user collapses to expose chat for screenshot)
      → .loading (intent is generating)
      → .replies([String]) (suggestions available)
      → .editReply(String) (user edits a suggestion inline)
      → .editContact(String) (user renames the detected contact)
      → .disambiguate(name:candidates:) (multiple contacts with same name)
      → .error(String)
```

`KeyboardModel` (`@MainActor ObservableObject`) holds state and exposes callbacks to `KeyboardViewController`, which wires them to the text document proxy (insert/delete text).

### Memory / contacts

Each successful capture creates a `CaptureSession` with `llmSummary` (one-sentence summary from LLM) and `contactID`. `AppGroupService.recentSummaries(forContactID:limit:)` retrieves past summaries to pass as `previousContext` to the LLM, giving it memory of past conversations with that contact.

### Tiers

- **Free**: 3 reply options, screenshot-only capture, daily limit enforced by KV rate limiter
- **Premium** (StoreKit transaction ID present): 5 reply options, scroll capture (up to 6 frames), no rate limit

The `transactionId` field in the request body is how the backend distinguishes tiers. The companion app writes the current StoreKit transaction ID to the App Group so intents can read it.

### Backend structure

```
backend/src/
  index.ts          # Hono app, mounts routes
  routes/
    reply.ts        # POST /reply (single screenshot or email text)
                    # POST /reply/scroll (multi-frame, premium-only)
    health.ts       # GET /health
  services/
    llm.ts          # LLM calls (Claude + GPT-4o), prompt construction, output parsing
    rateLimit.ts    # KV-backed daily rate limiter
  types/index.ts    # Env bindings, shared types
```

The LLM prompt always outputs: `CONTACT: …`, `SUMMARY: …`, then numbered replies. `parseLlmOutput()` in `llm.ts` parses this format — keep it in sync if you change the prompt format.

## Key design constraints

- The keyboard extension and companion app are separate processes. **Never call async APIs directly from the keyboard extension.** All heavy work (LLM calls) happens in `GenerateReplyIntent` running in the companion app process.
- `AppGroupService` uses `defaults.synchronize()` explicitly because extensions and the host app have separate UserDefaults caches.
- Keyboard height is hardcoded per state in `KeyboardViewController` (`280px` idle/loading/error, `320px` replies/disambiguate, `44px` collapsed) — iOS keyboard extensions cannot use dynamic/intrinsic sizing.
- `ReplrStrip` (the top action bar in idle/loading/error states) adapts content based on `KeyboardModel.state` and `lastInsertedReply` — undo chip takes priority over all other states.
