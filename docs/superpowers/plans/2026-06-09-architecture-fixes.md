# Architecture Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 2026-06-09 architecture-review findings: make the backend enforce access (rate limit + optional auth), move credits to a server-authoritative D1 ledger with StoreKit JWS verification, serve the model catalog from `/config`, fix the Back Tap memory contamination, add the StoreKit `Transaction.updates` listener, clean up the stale screenshot file, delete orphans, and refresh CLAUDE.md.

**Architecture:** Backend changes are rollout-safe: rate limiting applies immediately (generous limits), auth-required and sandbox-acceptance are env flags, and credit enforcement only applies to users whose server ledger row exists (created by the updated app via `/credits/migrate` or `/credits/redeem`) — old clients keep working until flags flip. The iOS app becomes a thin client: server balance mirrors into the App Group so the keyboard UI is unchanged.

**Tech Stack:** Cloudflare Workers (Hono, D1, KV), `jose` (already a dep) + `@peculiar/x509` (new) for StoreKit JWS chain verification, Vitest; iOS Swift/SwiftUI/StoreKit 2.

**Constraints (from HANDOFF.md):** Commit after each discrete change with `Co-Authored-By` trailer. NEVER `npm run deploy`, never push, never run remote D1 migrations — those are deploy-day steps for the user (Task 15 documents them).

**Verification gates:**
- Backend: `cd /Users/WORK2/Developer/Replr/backend && npm run typecheck && npm test`
- iOS: `cd /Users/WORK2/Developer/Replr/Replr && xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build`

---

## Task 1: Wire rate limiting + auth flag + `detail` gating into the reply routes

**Files:**
- Modify: `backend/src/services/rateLimit.ts`
- Modify: `backend/src/routes/reply.ts`
- Modify: `backend/src/types/index.ts` (Env additions)
- Modify: `backend/wrangler.toml` (new vars)
- Modify: `backend/tests/rateLimit.test.ts`, `backend/tests/reply.test.ts`, `backend/tests/scroll.test.ts`

- [ ] **Step 1.1: Rewrite the rate limiter (key-based, no dead "premium" tier)**

Replace the body of `backend/src/services/rateLimit.ts` with:

```ts
import type { KVNamespace } from '@cloudflare/workers-types'

/** Daily fixed-window limiter keyed by an arbitrary string (`user:<id>` or `ip:<addr>`).
 *  KV read-then-write is not atomic — concurrent requests can slightly exceed the
 *  limit. Acceptable for an abuse backstop; atomic would require a Durable Object. */
export async function checkRateLimit(
  kv: KVNamespace,
  key: string,
  limit: number
): Promise<boolean> {
  const today = new Date().toISOString().split('T')[0]
  const kvKey = `rate:${key}:${today}`
  const current = await kv.get(kvKey)
  const count = parseInt(current ?? '0', 10)

  if (count >= limit) return false

  await kv.put(kvKey, String(count + 1), { expirationTtl: 86400 })
  return true
}
```

- [ ] **Step 1.2: Update `rateLimit.test.ts` to the new signature** (drop tier tests, keep allow/deny/increment behavior; add a test that two different keys do not share a counter). Run `npm test -- tests/rateLimit.test.ts` → PASS.

- [ ] **Step 1.3: Env + wrangler vars**

`types/index.ts` Env gains:
```ts
  ANON_DAILY_LIMIT?: string         // default '50' in code
  REQUIRE_AUTH?: string             // 'true' → /reply rejects anonymous requests
  ALLOW_SANDBOX_TRANSACTIONS?: string  // 'true' while TestFlight is the audience
```

`wrangler.toml` `[vars]` gains:
```toml
ANON_DAILY_LIMIT = "50"
REQUIRE_AUTH = "false"
ALLOW_SANDBOX_TRANSACTIONS = "true"
```

- [ ] **Step 1.4: Failing route tests first** — in `reply.test.ts`: (a) 429 after limit exhausted for anonymous (KV mock returns count == limit), (b) 401 when `REQUIRE_AUTH='true'` and no Bearer, (c) `detail` absent for anonymous 500s, present for authenticated 500s. Both reply/scroll fakeEnvs need `RATE_LIMIT_KV` + `DB` mocks (copy the pattern from `auth.test.ts`; sessions SELECT returns `{ user_id: 'user-1' }` for a 64-char token).

- [ ] **Step 1.5: Implement the gate in `reply.ts`**

```ts
import type { Context } from 'hono'
import { checkRateLimit } from '../services/rateLimit'
import { sessionMiddleware, SESSION_USER_ID_KEY, type SessionVariables } from '../middleware/session'

type ReplyContext = Context<{ Bindings: Env; Variables: SessionVariables }>

/** Auth + abuse gate shared by both reply endpoints. Returns an error Response,
 *  or null when the request may proceed. Anonymous traffic is keyed by IP so a
 *  caller can't reset their quota by rotating the client-invented userId. */
async function enforceAccess(c: ReplyContext): Promise<Response | null> {
  const authedUserID = c.get(SESSION_USER_ID_KEY)
  if (!authedUserID && c.env.REQUIRE_AUTH === 'true') {
    return c.json({ error: 'Sign in required. Update the Replr app and sign in.' }, 401)
  }
  const key = authedUserID ? `user:${authedUserID}` : `ip:${c.req.header('CF-Connecting-IP') ?? 'unknown'}`
  const limit = authedUserID
    ? parseInt(c.env.FREE_DAILY_LIMIT, 10)
    : parseInt(c.env.ANON_DAILY_LIMIT ?? '50', 10)
  if (!(await checkRateLimit(c.env.RATE_LIMIT_KV, key, limit))) {
    return c.json({ error: 'Daily limit reached. Try again tomorrow.' }, 429)
  }
  return null
}
```

Call `const denied = await enforceAccess(c); if (denied) return denied` as the first statement of BOTH handlers. In both catch blocks (and scroll's), gate detail:

```ts
const body: Record<string, string> = { error: 'Failed to generate replies. Please try again.' }
if (c.get(SESSION_USER_ID_KEY)) body.detail = String((err as { message?: string })?.message ?? err)
return c.json(body, 500)
```

- [ ] **Step 1.6:** `npm run typecheck && npm test` → PASS. Commit: `feat(backend): enforce rate limits + REQUIRE_AUTH flag on /reply; gate error detail to signed-in callers`

## Task 2: D1 credits schema

**Files:** Create `backend/migrations/0002_create_credits.sql`

- [ ] **Step 2.1:**

```sql
-- Server-authoritative credit balances. `credits.balance` is the source of truth;
-- `credit_ledger` is the append-only audit trail (one row per grant/spend/refund).
CREATE TABLE IF NOT EXISTS credits (
  user_id     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance     INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL            -- Unix epoch seconds
);

CREATE TABLE IF NOT EXISTS credit_ledger (
  id          TEXT PRIMARY KEY,            -- crypto.randomUUID()
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta       INTEGER NOT NULL,            -- positive grant, negative spend
  reason      TEXT NOT NULL,               -- 'purchase' | 'migration' | 'spend' | 'refund'
  ref         TEXT UNIQUE,                 -- StoreKit transactionId for purchases (dedup); NULL otherwise
  created_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS credit_ledger_user ON credit_ledger(user_id);
```

- [ ] **Step 2.2:** `npx wrangler d1 migrations apply replr-db --local` → `✅`. (Remote apply = deploy day, Task 15.) Commit: `feat(backend): D1 schema for server-side credit ledger`

## Task 3: Model catalog as single source + `/config` exposure

**Files:** Create `backend/src/services/models.ts`; Modify `backend/src/routes/reply.ts`, `backend/src/routes/config.ts`, `backend/tests/config.test.ts`

- [ ] **Step 3.1: `models.ts`** — catalog (id/label/creditCost/production) for all 15 models, `DEFAULT_MODEL = 'gemini-3.5-flash'`, `VALID_MODELS = MODEL_CATALOG.map(m => m.id)`, `creditCostFor(model)` (fallback 7), and `CREDIT_PACKS` mapping the four `com.ihsan.replr.credits.*` product IDs to 100/300/750/2500. Credit costs MUST match `AppGroupService.creditsRequired` (Sonnet 8, GPT-5.4 7, Opus 15, Haiku 3, GPT-5.5 15, Pro 6, Pro-low 6, Flash-preview 3, 3.5-flash 4, flash-lite 2, 2.5-pro 4, grok-4 7, grok-4.3 2, 5.4-mini 2).
- [ ] **Step 3.2:** `reply.ts` imports `VALID_MODELS` from `../services/models` (delete the local copy). `config.ts` returns `{ shortcutInstallURL, defaultModel: DEFAULT_MODEL, models: MODEL_CATALOG }`.
- [ ] **Step 3.3:** Extend `config.test.ts`: response contains 15 models, each with `id/label/creditCost/production`, and `defaultModel === 'gemini-3.5-flash'`. `npm test` → PASS. Commit: `feat(backend): single model catalog served via /config`

## Task 4: StoreKit JWS verifier

**Files:** Create `backend/src/services/appstore.ts`, `backend/tests/appstore.test.ts`; Modify `backend/package.json` (add `@peculiar/x509`)

- [ ] **Step 4.1:** `npm install @peculiar/x509` (runtime dep).
- [ ] **Step 4.2: Failing tests first** (`tests/appstore.test.ts`): generate a 3-cert ES256 chain with `x509.X509CertificateGenerator` (root CA → intermediate CA with raw `Extension('1.2.840.113635.100.6.2.1', false, DER-NULL)` → leaf with `Extension('1.2.840.113635.100.6.11.1', ...)`), sign a payload with `jose` `CompactSign` + `x5c` header. Cases: valid chain returns payload; untrusted root rejected; missing leaf OID rejected; expired (pass `at` beyond notAfter) rejected; tampered payload rejected; 2-cert chain rejected. Tests pass `trustedRootsDER: [new Uint8Array(root.rawData)]`.
- [ ] **Step 4.3: Implement `appstore.ts`**: pinned `APPLE_ROOT_CA_G3_B64` (real DER from https://www.apple.com/certificateauthority/AppleRootCA-G3.cer, downloaded + openssl-verified: CN "Apple Root CA - G3", notAfter 2039); `verifyTransactionJWS(jws, opts)` — decode `x5c` (exactly 3), root byte-pinned against trusted roots, `intermediate.verify({publicKey: root.publicKey, date})` and `leaf.verify({publicKey: intermediate.publicKey, date})`, Apple marker OIDs required (skippable via `requireAppleOIDs:false` — used only by tests), `compactVerify` against the leaf key exported as ECDSA P-256, JSON-parse payload typed as `AppStoreTransactionPayload { bundleId, productId, transactionId, originalTransactionId, type, environment }`.
- [ ] **Step 4.4:** `npm run typecheck && npm test` → PASS. Commit: `feat(backend): StoreKit transaction JWS verifier with pinned Apple root`

## Task 5: Credits service + `/credits` routes

**Files:** Create `backend/src/services/credits.ts`, `backend/src/routes/credits.ts`, `backend/tests/credits.test.ts`; Modify `backend/src/index.ts`

- [ ] **Step 5.1: `credits.ts`** — `getBalance(db, userId): Promise<number | null>` (null = not server-managed); `grant(db, userId, delta, reason, ref)` as a `db.batch([ledger INSERT, credits upsert ON CONFLICT(user_id) DO UPDATE SET balance = balance + ?2])` — a UNIQUE violation on `ref` rejects the whole batch atomically → catch → `{ balance: current, granted: false }` (the double-redeem guard); `trySpend(db, userId, cost)` — single atomic `UPDATE credits SET balance = balance - ?2 WHERE user_id = ?1 AND balance >= ?2 RETURNING balance`, then best-effort 'spend' ledger row; returns new balance or null.
- [ ] **Step 5.2: Failing route tests** (`tests/credits.test.ts`): stateful fake D1 routing on SQL prefix (sessions SELECT → `{user_id:'user-1'}` only for the right token; SELECT balance → state; UPDATE…RETURNING → conditional decrement; batch → applies grant, throws `UNIQUE constraint failed: credit_ledger.ref` for duplicate refs). Mock `verifyTransactionJWS` via `vi.mock('../src/services/appstore')`. Cases: all three endpoints 401 without Bearer; GET / returns `{balance:0, serverManaged:false}` for new user, `{balance,serverManaged:true}` after grant; migrate caps claim at 3000, is idempotent (second call returns existing balance, `migrated:false`); redeem grants once then `granted:false` on duplicate transactionId; redeem rejects wrong bundleId / unknown productId / Sandbox when `ALLOW_SANDBOX_TRANSACTIONS !== 'true'`.
- [ ] **Step 5.3: `routes/credits.ts`** — `sessionMiddleware`, `APPLE_BUNDLE_ID = 'Theory-of-Web.Replr'` (matches `authRoute`'s audience), `MIGRATION_CAP = 3000`. `GET /` → balance; `POST /migrate {claimedBalance}` → ignore if row exists, else `grant(..., 'migration', null)` with clamped int; `POST /redeem {jws}` → verify (env-gated sandbox acceptance), bundleId check, `CREDIT_PACKS[productId]` lookup, `grant(..., 'purchase', transactionId)`. Mount `app.route('/credits', creditsRoute)` in `index.ts`.
- [ ] **Step 5.4:** `npm run typecheck && npm test` → PASS. Commit: `feat(backend): /credits routes — balance, one-time migration, StoreKit redeem with ledger dedup`

## Task 6: Spend enforcement in `/reply` + `creditsRemaining`

**Files:** Modify `backend/src/routes/reply.ts`, `backend/tests/reply.test.ts`

- [ ] **Step 6.1: Failing tests** — server-managed authed user: success response includes `creditsRemaining = balance - cost`; insufficient balance → 402 `{error:'insufficient_credits'}`; LLM throw → balance refunded (assert fake-D1 state); zero-parsed-replies 502 → refunded; anonymous / non-managed authed user → no `creditsRemaining`, no deduction.
- [ ] **Step 6.2: Implement** in both handlers after model validation:

```ts
const authedUserID = c.get(SESSION_USER_ID_KEY)
let charged = 0
let creditsRemaining: number | undefined
if (authedUserID) {
  const existing = await getBalance(c.env.DB, authedUserID)
  if (existing !== null) {   // server-managed → enforce
    const cost = creditCostFor(model)
    const newBalance = await trySpend(c.env.DB, authedUserID, cost)
    if (newBalance === null) return c.json({ error: 'insufficient_credits' }, 402)
    charged = cost
    creditsRemaining = newBalance
  }
}
```

Success: spread `...(creditsRemaining !== undefined ? { creditsRemaining } : {})` into the JSON. Both failure paths (catch AND the `replies.length === 0` 502) refund first: `if (charged && authedUserID) await grant(c.env.DB, authedUserID, charged, 'refund', null)`.
- [ ] **Step 6.3:** `npm run typecheck && npm test` → PASS. Commit: `feat(backend): authoritative credit spend in /reply with refund-on-failure`

## Task 7: iOS — ReplyService: `creditsRemaining`, 402, stale copy

**Files:** Modify `Shared/ReplyService.swift`

- [ ] `ReplyResponse` + `ReplyResult` gain `let creditsRemaining: Int?` (thread through all 3 generate functions). After the 401 check in each, add `if http.statusCode == 402 { throw ReplyError.insufficientCredits }`. New enum case `insufficientCredits` with description `"You're out of credits. Top up in the Replr app."`. Fix stale copy: `.rateLimitReached` → `"Daily limit reached. Try again tomorrow."`. Build → commit: `feat(ios): surface server credit state (creditsRemaining, 402) in ReplyService`

## Task 8: iOS — server credits client, purchase safety, sync hooks

**Files:** Create `Replr/Replr/Credits/CreditsService.swift`; Modify `Replr/Replr/Credits/CreditsManager.swift`, `Shared/Constants.swift`, `Shared/AppGroupService.swift`, `Replr/Replr/App/ReplrApp.swift`, `Replr/Replr/Services/AuthService.swift`

- [ ] **Step 8.1: Constants + AppGroupService** — keys `serverCreditsMigratedKey = "replr.credits.serverMigrated"`, `grantedTxIDsKey = "replr.credits.grantedTxIDs"`; `var serverCreditsMigrated: Bool` and `grantedTransactionIDs: [String]` + `recordGrantedTransactionID(_:)` (cap 50, FIFO).
- [ ] **Step 8.2: `CreditsService.swift`** (app target only) — Bearer-authed (`ReplyService.bootstrapAuthIfNeeded()` + `ReplyService.authToken`, throw `.notSignedIn` when nil): `fetchBalance() -> Int?` (nil when `serverManaged == false`), `migrate(claimedBalance:) -> Int`, `redeem(jws:) -> Int`.
- [ ] **Step 8.3: CreditsManager** — `applyGrant(for:jws:)`: server redeem → write App Group balance → `transaction.finish()`; `.notSignedIn` → local fallback grant guarded by `grantedTransactionIDs` → finish; other errors → do NOT finish (StoreKit redelivers). `purchase()` success path calls `applyGrant`. `startTransactionListener()` from `init`: detached task iterating `Transaction.unfinished` then `Transaction.updates` through the same handler (verified + known productID only). `serverMigrateIfNeeded()` (one-time, flag-guarded, claims current local balance) and `syncServerBalance()` (GET → write App Group + publish).
- [ ] **Step 8.4: Hooks** — `ReplrApp` scenePhase `.active` adds `Task { await CreditsManager.shared.serverMigrateIfNeeded(); await CreditsManager.shared.syncServerBalance() }`. `AuthService.signIn` success tail: same Task. `AuthService.signOut()`: `AppGroupService.shared.serverCreditsMigrated = false`.
- [ ] **Step 8.5:** Build → commit: `feat(ios): server-authoritative credits — redeem-first purchases, Transaction.updates listener, migrate+sync`

## Task 9: iOS — call sites adopt `creditsRemaining` (+ QuickReplyIntent gate)

**Files:** Modify `Replr/Replr/Intents/GenerateReplyIntent.swift`, `Replr/Replr/Intents/QuickReplyIntent.swift`, `ReplrKeyboard/Views/KeyboardView.swift`, `ReplrKeyboard/KeyboardViewController.swift`

- [ ] In all four generation sites, replace the local deduction with: `if let remaining = result.creditsRemaining { AppGroupService.shared.creditBalance = remaining } else { <existing local deduction> }`. QuickReplyIntent currently deducts NOTHING — add the same credit gate + deduction GenerateReplyIntent has.
- [ ] Insufficient-credit handling: keyboard paths add `catch ReplyError.insufficientCredits { withAnimation { state = .paywall } }`; intents catch it and `saveError("insufficient_credits")`; verify how the poll/ErrorPanel handles that sentinel today (it is already written by the local gate) and map it to `.paywall` in `startCapturePoll` if it isn't already.
- [ ] Build → commit: `feat(ios): adopt server creditsRemaining at all generation sites; credit-gate QuickReplyIntent`

## Task 10: iOS — Back Tap memory contamination fix

**Files:** Modify `Replr/Replr/Intents/GenerateReplyIntent.swift` (and same pattern in `QuickReplyIntent.swift`)

- [ ] Before the memory read, clear the stale contact (mirrors the keyboard paths): `AppGroupService.shared.currentContactID = nil`; collapse the now-constant memory block to `let previousContext: String? = nil` + `AppGroupService.shared.memoryUsedContactName = nil`, with a comment noting memory re-enters via keyboard Regenerate after `resolveContact` identifies the contact. Build → commit: `fix(ios): stop Back Tap captures inheriting the previous contact's memory`

## Task 11: iOS — stale screenshot cleanup

**Files:** Modify `Shared/AppGroupService.swift`, `Replr/Replr/App/ReplrApp.swift`

- [ ] `AppGroupService.deleteStaleScreenshot(maxAge: TimeInterval = 3600)` — remove `screenshot.png` when mtime older than maxAge (Regenerate within an active session unaffected). Call from the scenePhase `.active` block. Build → commit: `fix(ios): delete the shared chat screenshot after 1h instead of keeping it indefinitely`

## Task 12: iOS — consume the remote model catalog

**Files:** Modify `Shared/Constants.swift`, `Shared/AppGroupService.swift`, `Replr/Replr/App/ReplrApp.swift` (RemoteConfig)

- [ ] Constants: `remoteModelCatalogKey = "remote_model_catalog"`. AppGroupService: top-level `struct RemoteModelInfo: Codable { id, label, creditCost, production }` + `var remoteModelCatalog: [RemoteModelInfo]` (JSON in App Group). `creditsRequired` consults the cached catalog first, falls back to the existing switch. RemoteConfig: rename to `refresh()`, decode `models` + `shortcutInstallURL`, store both. Build → commit: `feat(ios): credit costs driven by the /config model catalog with baked-in fallback`

## Task 13: Hygiene deletions

- [ ] Re-verify zero references, then delete: repo-root `ReplrBroadcast/` (orphaned older copy; active target uses `Replr/ReplrBroadcast/` via synchronized group), `Replr/Replr/AnalyzeScreenshotIntent.swift` (empty `perform()`), `Replr/Replr/ToggleScrollCaptureIntent.swift` (help-text placeholder; not in AppShortcutsProvider). Build → commit: `chore: delete orphaned broadcast handler and dead intents`. Dismiss the session's spawned background-task chips (now done inline).

## Task 14: CLAUDE.md refresh

- [ ] Rewrite stale sections to match reality: two generation paths (intent-process AND in-keyboard direct calls), 250ms poll, current `KeyboardState` cases, credits system (server ledger when signed-in + migrated; packs; dev mode), backend route list (auth/credits/config), model-catalog single source. Commit: `docs: CLAUDE.md matches the post-fixes architecture`

## Task 15: Final verification + deploy-day runbook (DOCUMENT ONLY — do not execute)

- [ ] Full gates: backend `npm run typecheck && npm test`; iOS build. Update `docs/HANDOFF.md` with a "Deploy day" section: 1) `npx wrangler d1 migrations apply replr-db --remote` 2) `npm run deploy` 3) ship the app update 4) later flip `REQUIRE_AUTH = "true"` and (at public launch) `ALLOW_SANDBOX_TRANSACTIONS = "false"`. Commit: `docs: deploy-day runbook for enforcement rollout`

---

## Self-review notes

- Spec coverage: review items 1→Task 1+6, 2→Tasks 2,4,5,6,8,9, 3→Task 10, 4→Task 8, 5→Tasks 3+12, 6→Tasks 1 (detail) + 11, 7→Tasks 13+14. ✓
- Rollout safety: old clients hit only the new rate limit (anon 50/day by IP) until `REQUIRE_AUTH` flips; credit enforcement is opt-in per user via row existence. ✓
- Type consistency: `creditsRemaining: Int?` (iOS) ↔ `creditsRemaining?: number` (backend); sentinel string `insufficient_credits` shared by 402 body, intent saveError, and keyboard poll mapping. ✓
