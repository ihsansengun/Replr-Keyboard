# Session handoff — 2026-06-07

This documents the project state for the next working session. The repo was moved
out of iCloud today; start fresh sessions from this folder (`~/Developer/Replr`).

---

## 0. Where things are (READ FIRST)

- **Canonical repo: `/Users/WORK2/Developer/Replr`** (moved here 2026-06-07 because the
  old path `~/Desktop/DesktopCloud/Replr` is under iCloud, which evicted `.git` pack
  objects on a near-full disk and broke git).
- **`origin/main` = `fb9975d`** — everything below is merged + pushed. Branch from `main`.
- Old `~/Desktop/DesktopCloud/Replr` = frozen backup, safe to delete once you're happy.
- Disk was ~98% full — free space so iCloud/Xcode don't choke.
- Uncommitted (intentionally carried, not committed): `backend/package.json` +
  `package-lock.json` wrangler downgrade (`^3.74.0` working vs `^4.90.1` committed) —
  **reconcile before next deploy**. Plus untracked `docs/design/screenshots/IMG_*.PNG`.
- Cosmetic broken local refs (local-only objects iCloud lost; not on origin; harmless):
  branch `worktree-feat+payment-paywall`, tag `phase1-keyboard`. Delete if you want a
  clean `git fsck`.

---

## 1. DONE — keyboard replies-height fix (verified on device 2026-06-07)

**Requirement (firm):** the keyboard always shows all **3 replies, no scroll, fitting
exactly** — no clip, no gap — and the height is **dynamic to the line counts** (the CSS
`height: auto` equivalent). Reproduce in onboarding "Practice" (that's the real keyboard).

**Current fix (`fb9975d`)** in `ReplrKeyboard/Views/RepliesPanelView.swift` +
`ReplrKeyboard/KeyboardViewController.swift`:
- Panel is a **plain `VStack` (no ScrollView)**. Each piece (header, cards, action row)
  reports its height via `.background(heightReporter)` → a **summing** `ContentHeightKey`
  → `onContentHeightChanged(sum)` → `setHeight(clamp 300...600)`. `lastRepliesContentHeight`
  remembers the measured value (used as the `.replies` placeholder).

**Status: RESOLVED — confirmed working on device 2026-06-07.** Kept here (with the rejected
approaches in memory) in case of regression. **The top priority is now §1B (screenshot rework).**

**Rejected approaches — do not repeat** (see
`~/.claude/projects/-Users-WORK2-Developer-Replr/memory/project_keyboard_replies_height.md`):
boundingRect estimate (gap), `sizeThatFits`+ScrollView (clip — ScrollView hides content
height), single outer GeometryReader (reads frame back — gap).

**If still wrong:** add a temporary on-screen height readout so a screenshot reveals the
exact measured number, then tune. (Offered to the user.)

---

## 1B. PRIORITY (next session) — Screenshot capture rework: native-first, bypass Back Tap

Make the **native screenshot the primary capture path** and drop the dependency on the
optional **Back Tap → Shortcut** setup. The core ("kernel") logic should continuously detect
newly-generated screenshots and cache them for the keyboard — even when the keyboard (or app)
was NOT open at capture time.

Why Back Tap exists today (the two advantages to preserve):
1. It auto-deletes the captured shot on the fly so screenshots don't pile up in Photos
   (nice-to-have, not critical — already partly handled by `ScreenshotCleaner` / auto-clear).
2. It works without the keyboard being activated — the user can screenshot anything, anytime.

Target: keep #1 + #2 while removing the Back Tap setup step (lower onboarding friction).

Investigate first (verify-before-claiming): iOS restricts background Photos monitoring — a
keyboard extension only runs while active; the companion app only observes `PHPhotoLibrary`
while running. "Always listening even when nothing is open" likely has to be realized as: on
next keyboard/app open, scan Photos for screenshots created since a stored baseline and
surface them (extends the existing `detectedScreenshotID` flow + `ScreenshotCleaner` from
Phase 1/2). Confirm what's actually achievable before designing. This also overlaps the
deferred "Phase 3" onboarding restructure (formally demote Back Tap). Task #88; see memory
`project_screenshot_capture.md`.

---

## 1C. Enforcement rollout — DEPLOYED 2026-06-09 (steps 1–3 done, 4–5 remaining)

The architecture fixes (rate limiting, server credit ledger, StoreKit JWS redeem,
model catalog, contamination fix, purchase-safety listener) are **merged to `main`
and the backend is LIVE** (worker version `58c1b640`, D1 migration 0002 applied
remotely, verified: /health ok, /config serves 15 models, /credits 401s unauth,
anonymous /reply generates with per-IP limiting). Backward-compatible: old clients
are only rate-limited (anon 50/day per IP); credit enforcement starts per-user
after the updated app calls `/credits/migrate` or `/redeem`.

**Second deploy (worker `a16a9ad5`, migration 0003 remote):** tiered rate
limits (credit-metered users get a 1000/day circuit breaker — credits are
their real meter) and the `users.is_dev` exemption (dev mode is test-only;
dev accounts are never charged server credits). `is_dev=1` is SET for the
dev account (ihsansengun@me.com). Prod re-probed green.

**Third deploy (2026-06-10):** `ANON_DAILY_LIMIT` 50 → 120 (carrier-NAT IP
pooling — old-build TestFlight testers share per-IP quota). All work pushed
to origin/main.

### Paywall A/B experiments (added 2026-06-10)

**Full owner's guide: `docs/PAYWALL_EXPERIMENTS.md`** (step-by-step incl. the
App Store Connect work). Quick reference below.

- **Launch a test:** edit `ACTIVE_PAYWALL_EXPERIMENT` in
  `backend/src/services/paywall.ts` (bump `key` to re-bucket, add weighted
  variants), `npm run deploy`. Assignment is a pure hash — no storage, the
  same user always sees the same variant for a given key, and purchases are
  attributed server-side so clients can't lie.
- **Price tests:** create alternate products in App Store Connect as SEPARATE
  product ids (e.g. `com.ihsan.replr.credits.300.p299` = 300 credits at £2.99)
  — they must be added to `CREDIT_PACKS` in `services/models.ts` and referenced
  in a variant's `productIDs`. The iOS side needs no release: it renders
  whatever list `/paywall` serves and parses credit counts from the id.
- **Read results:**
  `npx wrangler d1 execute replr-db --remote --command "SELECT experiment, variant, event, COUNT(DISTINCT user_id) users, COUNT(*) n FROM paywall_events GROUP BY 1,2,3"`
  (impressions vs purchases per variant; conversion = purchase users / impression users).
- **ASC prerequisite (also blocks ALL revenue):** the four baseline IAPs must
  be created in App Store Connect with the CODE's ids (`com.ihsan.replr.credits.*`
  — NOT the `Theory-of-Web.*` ids in the old monetisation spec).
- Caveat: TestFlight cohorts are too small for significance — this infra is
  for post-launch traffic. Don't read noise as signal.
- Remote D1 migration 0004 (paywall_events) pending next deploy.

### Dating mode (built 2026-06-10 — LAUNCH BLOCKER per user decision)

Full dating mode shipped in code: third keyboard mode, separate prompt family,
11 dating tones + 4 shared (default Tease), always-on match memory, Settings
Dating section. Spec: `docs/superpowers/specs/2026-06-10-dating-mode-design.md`;
plan: `docs/superpowers/plans/2026-06-10-dating-mode.md`. **Backend DEPLOYED**
(worker `2c4946d3` dating family → `a7b8e042` + the "sound like a person"
humanizer). Production probes verified: profile → lowercase thumb-typed
openers anchored to profile details (CONTEXT=profile), ongoing chat → Closer
closing with day+number (CONTEXT=chat). Remaining: USER DEVICE PASS (run app
from Xcode — TestFlight build predates dating mode): profile → openers; empty
chat → pick-up lines; ongoing → continuation; tone row per mode; Settings
Dating section; Back Tap with dating persisted. Tone voices are server-side —
quality tweaks are edit+deploy, no rebuild.

Remaining (user-triggered):

4. Ship the app update (server credits + purchase-safety listener, 100-credit
   trial, catalog cache, contamination fix, paywall variants, DATING MODE) —
   next TestFlight/App Store build from Xcode.
5. Later, flip `wrangler.toml` flags + redeploy:
   - `REQUIRE_AUTH = "true"` once un-signed-in clients are negligible (check
     anonymous traffic via `npx wrangler tail` first — public TestFlight link).
   - `ALLOW_SANDBOX_TRANSACTIONS = "false"` at public App Store launch
     (keep "true" while TestFlight is the audience).
6. Optional: gift existing testers ~100 credits once they've migrated
   (`UPDATE credits SET balance = balance + 100 WHERE user_id='<id>'`) — the
   bigger starting grant only applies to fresh installs.

Detail: `docs/superpowers/plans/2026-06-09-architecture-fixes.md`.

---

## 2. Standing constraints (from the user — keep following)

- **Never push / merge / deploy without an explicit ask.** (The 2026-06-07 merge+push of
  `main` was explicitly requested.)
- **Commit after each discrete change.** End commit messages with a
  `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer (use the current
  model from the system prompt).
- **Read `DESIGN.md` before any UI work. Never hardcode colors/fonts/spacing — use
  `ReplrTheme.*`.** Verify dark AND light.
- **Verify before claiming** — read/grep/build to confirm; don't argue from a screenshot.
- **"Review the whole architecture later"** for credits/monetization — defer building the
  ledger until then.
- SourceKit errors like "No such module 'UIKit'/'Lottie'" or "Cannot find
  'ReplrTheme'/'KeyboardModel'/'AppGroupService'" are **false positives** — `xcodebuild`
  is the source of truth.

---

## 3. What shipped recently (this session, all on `main`)

- **Keyboard CTAs**: consistent system — gradient capsule = primary, outlined = secondary.
  `✨ Start`; "Try again" now actually regenerates; open-keyboard capture (no Start tap) →
  opt-in "tap to generate" chip.
- **Models**: added **Gemini 3.5 Flash (now DEFAULT)**, Gemini 3.1 Pro (2nd), 3.1 Flash
  Lite, 2.5 Pro; Claude Opus 4.7 + Haiku 4.5. Fixed GPT-5.x (use `max_completion_tokens`;
  `temperatureLocked` for gpt-5.5 + claude-opus-4-7 which reject non-default temperature).
- **Model tester** in companion app (`ModelPickerView` "Test all models", per-row ✓/✗ via
  `ReplyService.testModel`; surfaces the backend `detail` error string).
- **Tutorial deep-link**: keyboard "Show me how" → `replr://tutorial/steer` opens
  `UsageTutorialView` directly on the Steer step (custom `init` with `State(initialValue:)`).
- **Memory wedge part 1**: cross-contamination kill + `normalizeContactName` (moved into
  `Shared/AppGroupService.swift` for per-target membership) + tests.
- **Trust quick wins** from the SmoothSpeak teardown ("Free to try — no credit card", etc.).

### Where models are registered (touch ALL of these when adding one)
- Backend: `types/index.ts` Model union; `services/llm.ts` `resolveModel()` + `PRICING`;
  `routes/reply.ts` `VALID_MODELS`.
- App: `Replr/Credits/ReplrModel.swift` enum (6 exhaustive switches);
  keyboard `DevModelOption.all`; `AppGroupService` `creditsRequired` +
  `selectedModelShortLabel`.

---

## 4. Pending / next tasks

1. **Verify the replies-height fix on device** (section 1) — highest priority.
2. **Memory wedge part 2** (approved, not built): proactive "I remember [Name] — tap to
   use" chip + auto-disambiguate when >1 contact matches a name.
3. **Unify the model registry** (keyboard `DevModelOption` vs app `ReplrModel`) — was a
   spawned background task.
4. **Tone→model routing** (`ToneSpec.preferredModel`) — future, backend-only; Gemini
   seemed better for Joker. See memory `project_tone_model_routing.md`.
5. **Reconcile the backend wrangler downgrade** (uncommitted) before next deploy.
6. **Delete vestigial `trialUsedCount`** — careful, it's read by the credits migration.
7. **Relationship dynamic per contact** — PARKED (needs keyboard UX decision).

### Competitor teardown (SmoothSpeak — AI Dating Coach), key finding
Trust/billing is their #1 crack (chargeback/auto-renew complaints); **reply quality is
NOT a crack**; memory is a smaller crack; scale is small/beatable. Chosen wedges:
**Trust & honesty positioning** + **Memory proof**. Replr's own trust posture audited
clean.

---

## 5. Build / test / deploy gates

```bash
# iOS (build gate)
cd ~/Developer/Replr/Replr && xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
# iOS tests: scheme ReplrTests (⌘U in Xcode)

# Backend
cd ~/Developer/Replr/backend && npm run typecheck && npm test
cd ~/Developer/Replr/backend && npm run deploy   # only when explicitly asked

# Production probe
curl https://api.replr.app/reply -d '{"emailText":"...","tone":"natural","toneName":"Natural","model":"<id>","userId":"diag-..."}'
npx wrangler tail --format pretty   # raw server errors
```

### Architecture quick map
- iOS app + the keyboard extension share `Shared/` via App
  Group `group.com.ihsan.replr` through `AppGroupService.shared`. **`Shared/` files have
  per-target membership — a helper used by multiple targets must live in a file compiled
  into all of them** (e.g. `AppGroupService.swift`), not one some targets exclude.
- Reply flow: capture → `GenerateReplyIntent` → `ReplyService.generateReplies()` POSTs to
  `https://api.replr.app/reply` → backend `routes/reply.ts` → `services/llm.ts`
  (`parseLlmOutput` expects `CONTACT:` / `SUMMARY:` / numbered replies) → results to App
  Group → keyboard polls App Group every 1s.
- **Never call async APIs from the keyboard extension** — heavy work runs in
  `GenerateReplyIntent` (companion app process).
