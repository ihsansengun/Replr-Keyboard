# Paywall A/B Testing + Remote Pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remotely control which credit packs the paywall shows (products, order, badge, headline) per A/B variant, with deterministic per-user assignment and a D1 event log (impressions + purchases) so variants can be compared — all changeable by redeploying the worker, no App Store release.

**Architecture:** A new authenticated `GET /paywall` returns the caller's assigned variant (pure function: SHA-256 of `experimentKey:userId` → weighted bucket — no assignment storage needed, stable forever per experiment key). `POST /paywall/event` logs impressions; `/credits/redeem` logs purchases with the same server-computed variant, so the client can never misreport its bucket. The app caches the variant payload in the App Group; `CreditsManager`/`CreditPacksView` render whatever product list the server sent, falling back to the baked-in four. Price tests = create alternate products in App Store Connect (e.g. same 300 credits at a different price point) and serve different `productIDs` per variant; `CREDIT_PACKS` on the backend is the superset so redemption grants correctly for any variant.

**Tech Stack:** Existing Hono/D1/Vitest backend patterns (helpers.ts fake D1), SwiftUI + ReplrTheme (read DESIGN.md before the badge UI), StoreKit 2.

**Privacy note (flag to user, already accepted in spirit):** this adds the app's first telemetry — paywall impressions/purchases keyed by account id, no content, no device fingerprinting. Consistent with the trust positioning if disclosed; it is purchase-flow analytics, not usage tracking.

**Constraints:** Commit per task with Co-Authored-By trailer. No deploy / push / remote migration without an explicit ask. Backward compatible: old clients never call `/paywall` and keep the baked-in packs.

---

## Task 1: Backend — experiment definition + deterministic assignment

**Files:** Create `backend/src/services/paywall.ts`, `backend/tests/paywall.test.ts`

- [ ] Define `PaywallVariant { name, weight, productIDs, badgeProductID?, heroCopy? }`, `PaywallExperiment { key, variants }`, and `ACTIVE_PAYWALL_EXPERIMENT` (initial: key `paywall-baseline`, single `control` variant = current four packs, badge on `com.ihsan.replr.credits.300`). Comment shows how to launch a real test: bump `key`, add variants with weights.
- [ ] `assignVariant(experiment, userId)`: SHA-256(`${key}:${userId}`) → first 4 bytes as uint32 → weighted pick. Deterministic, uniform, no storage.
- [ ] Tests: same user+key → same variant always; distribution over 1,000 fake uids within ±10% of weights; changing key reshuffles. Run → commit `feat(backend): paywall experiment definitions + deterministic assignment`.

## Task 2: Backend — D1 events table + /paywall routes + purchase logging

**Files:** Create `backend/migrations/0004_create_paywall_events.sql`, `backend/src/routes/paywall.ts`; Modify `backend/src/index.ts`, `backend/src/routes/credits.ts`, `backend/src/services/models.ts` (CREDIT_PACKS comment: superset of ALL variants' products), `backend/tests/helpers.ts` (paywall_events insert routing), `backend/tests/credits.test.ts`

- [ ] Migration: `paywall_events(id PK, user_id FK, experiment, variant, event 'impression'|'purchase', product_id NULL, created_at)` + index on (experiment, variant, event). Apply `--local` only.
- [ ] `GET /paywall` (session required, 401 otherwise): returns `{ experiment, variant, productIDs, badgeProductID, heroCopy }` via `assignVariant`.
- [ ] `POST /paywall/event` (session required): body `{ event: 'impression' }` only (purchases are server-recorded); inserts row with server-computed variant. Rate-limited implicitly by auth; idempotency not needed (impressions are counts).
- [ ] `/credits/redeem`: after a `granted: true` redeem, best-effort insert a `purchase` event with the computed variant + productId (failure must not fail the redeem).
- [ ] Tests: 401s; impression insert carries server-computed variant; redeem logs purchase once (not on duplicate); analysis query smoke (`SELECT variant, event, COUNT(*)`). Run all → commit `feat(backend): /paywall variant endpoint + impression/purchase event log`.

## Task 3: iOS — variant consumption + dynamic packs + badge UI + impression ping

**Files:** Modify `Shared/Constants.swift` (`remotePaywallConfigKey = "remote_paywall_config"`), `Shared/AppGroupService.swift` (`RemotePaywallConfig: Codable` + cached var, same pattern as `RemoteModelInfo`), Create `Replr/Replr/Credits/PaywallService.swift` (authed fetch → cache; CreditsService-style), Modify `Replr/Replr/Credits/CreditsManager.swift` (productIDs from cache, fallback baked-in four), `Replr/Replr/App/ReplrApp.swift` (fetch alongside `RemoteConfig.refresh()` + on scenePhase active), `Replr/Replr/Credits/CreditPacksView.swift` (order per served list, "MOST POPULAR" badge on `badgeProductID`, optional heroCopy, fire-and-forget impression POST in `.task`)

- [ ] **Read DESIGN.md before the badge UI** (project rule). Badge: small capsule, `ReplrTheme` tokens only, verify dark + light.
- [ ] Build → commit `feat(ios): paywall renders server-assigned variant; impression telemetry`.

## Task 4: Docs + ASC runbook

**Files:** Modify `docs/HANDOFF.md`, `CLAUDE.md`

- [ ] HANDOFF: "Paywall experiments" section — how to launch a test (edit `ACTIVE_PAYWALL_EXPERIMENT`, deploy), how to read results (`npx wrangler d1 execute replr-db --remote --command "SELECT experiment, variant, event, COUNT(DISTINCT user_id) u, COUNT(*) n FROM paywall_events GROUP BY 1,2,3"`), and the **App Store Connect step**: create the four baseline products with the code's IDs, plus any price-test alternates as separate products (e.g. `com.ihsan.replr.credits.300.p299` = 300 credits at £2.99) which must also be added to `CREDIT_PACKS`. Note: TestFlight cohorts are too small for significance — infra is for launch.
- [ ] CLAUDE.md: one paragraph under Credits about the paywall variant flow. Commit `docs: paywall experiment runbook`.

## Task 5: Verification

- [ ] Backend `npm run typecheck && npm test`; iOS build gate. Deploy + remote migration are user-triggered (ask at the end).

## Self-review

- Variant integrity: client never sends its variant — server recomputes from session uid at impression AND purchase time. Same experiment key ⇒ same bucket at both moments. ✓
- Old clients: never call /paywall, baked-in packs, no events — unaffected. ✓
- Type consistency: `RemotePaywallConfig.productIDs: [String]` ↔ backend `productIDs: string[]`; badge id optional both sides. ✓
