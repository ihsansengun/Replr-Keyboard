# "About Me" + Gender-Aware Replies — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the reply model the context it's missing — the user's own identity (via an optional "About Me" field) and explicit reasoning about the recipient's gender — so replies use the right voice, gender, and grammar.

**Architecture:** One optional free-text "About You" field in Settings → stored in the App Group → sent as an optional `aboutUser` on every reply request → injected as a system-prompt profile block. The backend prompt also gains explicit recipient-gender reasoning (helps even when About Me is blank). No new server-side storage.

**Tech Stack:** SwiftUI + App Group (iOS), Hono + TypeScript on Cloudflare Workers (backend), Vitest. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-05-about-me-gender-aware-replies-design.md`

---

## ⚠️ Pre-existing test state (read first)

`cd backend && npm test` is **already red** before this work: ~7 failures from **stale fixtures unrelated to this feature** — `reply.test.ts`/`scroll.test.ts` use retired model IDs (`gpt-4.1-mini`), and `llm.test.ts`'s `generateReplies` tests assert `max_tokens: 1024` while the code uses `2048`. **Do not try to fix these here** (out of scope). Instead, verify this feature with a **pure, isolated** test (`buildSystemPrompt`) run by name, which is immune to that breakage. (Flag the stale suite to the user as separate cleanup.)

## File map

| File | Change |
|---|---|
| `backend/src/services/llm.ts` | extract pure `buildSystemPrompt(tone, aboutUser?)`; add `aboutUser?` to 3 param types; use it in the 3 generators; add gender reasoning to `DECISIONS` |
| `backend/tests/llm.test.ts` | add pure `describe('buildSystemPrompt')` tests |
| `backend/src/routes/reply.ts` | accept optional `aboutUser` on `/reply` + `/reply/scroll`, thread to services |
| `Shared/Constants.swift` | add `aboutUserKey` |
| `Shared/AppGroupService.swift` | add `aboutUser` accessor |
| `Shared/ReplyService.swift` | add `aboutUser?` to 3 request structs + populate from App Group |
| `Replr/Replr/Features/Settings/SettingsView.swift` | add "About You" section + `@State` |

**Build/verify commands** (used throughout):
- Backend pure test: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm test -- -t buildSystemPrompt`
- Backend types: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm run typecheck`
- iOS build: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/Replr && xcodebuild -project Replr.xcodeproj -scheme Replr -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build 2>&1 | tail -5` → `** BUILD SUCCEEDED **`. (SourceKit "No such module / Cannot find ReplrTheme" are FALSE POSITIVES; only xcodebuild counts. Use `iPhone 17`.)

---

### Task 1: Backend — `buildSystemPrompt` + the "About" block (TDD)

**Files:**
- Modify: `backend/src/services/llm.ts`
- Test: `backend/tests/llm.test.ts`

- [ ] **Step 1: Write the failing test** — append this `describe` block to `backend/tests/llm.test.ts` (after the existing `parseLlmOutput` block; also add `buildSystemPrompt` to the import on line 2):

Change the import line 2 from:
```ts
import { parseReplies, parseLlmOutput, generateReplies } from '../src/services/llm'
```
to:
```ts
import { parseReplies, parseLlmOutput, generateReplies, buildSystemPrompt } from '../src/services/llm'
```

Append:
```ts
describe('buildSystemPrompt', () => {
  it('always includes the Replr identity and the role/tone', () => {
    const sys = buildSystemPrompt('flirty')
    expect(sys).toContain('You are Replr')
    expect(sys).toContain('ROLE: flirty')
  })

  it('includes the ABOUT-THE-USER block when aboutUser is provided', () => {
    const sys = buildSystemPrompt('casual', '27, guy, into climbing and techno')
    expect(sys).toContain('ABOUT THE USER')
    expect(sys).toContain('27, guy, into climbing and techno')
  })

  it('omits the ABOUT block when aboutUser is undefined, empty, or whitespace', () => {
    expect(buildSystemPrompt('casual')).not.toContain('ABOUT THE USER')
    expect(buildSystemPrompt('casual', '')).not.toContain('ABOUT THE USER')
    expect(buildSystemPrompt('casual', '   ')).not.toContain('ABOUT THE USER')
  })

  it('trims the aboutUser text', () => {
    const sys = buildSystemPrompt('casual', '  hi there  ')
    expect(sys).toContain('hi there')
    expect(sys).not.toContain('  hi there  ')
  })
})
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm test -- -t buildSystemPrompt`
Expected: FAIL — `buildSystemPrompt is not a function` (or import error).

- [ ] **Step 3: Implement `buildSystemPrompt`** in `backend/src/services/llm.ts`. Add this exported function immediately after the `DECISIONS` constant (around line 39) and before `const REPLY_COUNT = 3`:

```ts
/** Build the system prompt: identity + role/tone, plus an optional user-profile
 *  block (the right-side person we write FOR — gives the model their voice/gender). */
export function buildSystemPrompt(tone: string, aboutUser?: string): string {
  const parts = [IDENTITY, `ROLE: ${tone}`]
  const about = aboutUser?.trim()
  if (about) {
    parts.push(
      `ABOUT THE USER YOU'RE WRITING FOR (the right-side person — write in their voice):\n${about}`
    )
  }
  return parts.join('\n\n')
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm test -- -t buildSystemPrompt`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/llm.ts backend/tests/llm.test.ts
git commit -m "backend: extract buildSystemPrompt with optional About-the-user block

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Backend — thread `aboutUser` through + gender reasoning

**Files:**
- Modify: `backend/src/services/llm.ts`
- Modify: `backend/src/routes/reply.ts`

- [ ] **Step 1: Add `aboutUser?` to the three param interfaces** in `llm.ts`. In `GenerateEmailParams`, `GenerateParams`, and `GenerateMultipleParams` (around lines 250-284), add this line alongside the existing `previousContext?: string`:

```ts
  aboutUser?: string
```

- [ ] **Step 2: Use `buildSystemPrompt` in all three generators.** In `generateReplies`, `generateRepliesFromMultiple`, and `generateRepliesFromEmail`, destructure `aboutUser` and replace the system construction.

In each function, add `aboutUser` to the destructure, e.g. in `generateReplies`:
```ts
  const { screenshotBase64, tone, summary, previousContext, aboutUser, model, anthropicKey, openaiKey, xaiKey, googleKey } = params
```
(Do the same for `generateRepliesFromMultiple` — destructures `screenshots,…` — and `generateRepliesFromEmail` — destructures `emailText,…`.)

Then in each of the three, replace:
```ts
  const system = [IDENTITY, `ROLE: ${tone}`].join('\n\n')
```
with:
```ts
  const system = buildSystemPrompt(tone, aboutUser)
```

- [ ] **Step 3: Add recipient-gender reasoning to `DECISIONS`.** Replace the `DECISIONS` constant (lines 33-39) with:

```ts
const DECISIONS = `Before generating replies, assess:
1. Language → detect it, then think natively in it. Do NOT draft in English and translate — ask yourself "what would a local person actually say?" and write that, using real idioms and cultural expressions, not English patterns in foreign words
2. Conversation energy → match it
3. Typical message length → stay consistent
4. What the most recent LEFT-side message implies → that is what you are replying to
5. Whether to advance the conversation or simply respond
6. Gender → infer the LEFT-side person's likely gender from their name, how the user addresses them, and the content; take the user's own gender from the ABOUT THE USER block (if provided). In grammatically-gendered languages get the gendered forms right for BOTH people; when a person's gender is genuinely unclear, prefer neutral phrasing over guessing. Reflect the real dynamic between the two (the flirt reads differently depending on who is writing to whom)
7. For dating contexts: where are they in the relationship?`
```

- [ ] **Step 4: Thread `aboutUser` through the route.** In `backend/src/routes/reply.ts`:

In the `/` handler, change the destructure (line 17-18) to include `aboutUser`:
```ts
  const { screenshotBase64, emailText, tone, summary, previousContext, aboutUser, model, userId } =
    body as Record<string, string | undefined>
```
Add `aboutUser,` to BOTH the `generateRepliesFromEmail({…})` and `generateReplies({…})` calls (next to `previousContext,`).

In the `/scroll` handler, change the destructure (line 61-62) to:
```ts
  const { screenshots, tone, model, userId, summary, previousContext, aboutUser } =
    body as { screenshots?: string[], tone?: string, model?: string, userId?: string, summary?: string, previousContext?: string, aboutUser?: string }
```
Add `aboutUser,` to the `generateRepliesFromMultiple({…})` call.

- [ ] **Step 5: Typecheck + the pure test still pass**

Run: `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm run typecheck && npm test -- -t buildSystemPrompt`
Expected: typecheck exits 0 (no errors); the 4 `buildSystemPrompt` tests PASS. (The pre-existing stale-fixture failures elsewhere are untouched and out of scope.)

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add backend/src/services/llm.ts backend/src/routes/reply.ts
git commit -m "backend: thread aboutUser into prompts + add gender reasoning to DECISIONS

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: iOS — App Group storage for `aboutUser`

**Files:**
- Modify: `Shared/Constants.swift`
- Modify: `Shared/AppGroupService.swift`

- [ ] **Step 1: Add the key.** In `Shared/Constants.swift`, add next to the other keys (after `persistRepliesKey`):

```swift
    static let aboutUserKey = "about_user"
```

- [ ] **Step 2: Add the accessor.** In `Shared/AppGroupService.swift`, immediately after the `persistReplies` computed property (around line 213), add:

```swift
    /// Free-text "About You" the user writes about themselves; sent per-request to steer replies.
    var aboutUser: String {
        get { defaults.string(forKey: Constants.aboutUserKey) ?? "" }
        set { defaults.set(newValue, forKey: Constants.aboutUserKey); defaults.synchronize() }
    }
```

- [ ] **Step 3: Build**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/Constants.swift Shared/AppGroupService.swift
git commit -m "iOS: App Group storage for aboutUser (About You)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: iOS — send `aboutUser` in the reply request

**Files:**
- Modify: `Shared/ReplyService.swift`

- [ ] **Step 1: Add the field to all three request structs.** Add `let aboutUser: String?` to `ReplyRequest` (after `userId`, line 10), `ReplyEmailRequest` (after `userId`, line 19), and the inline `struct ScrollRequest` inside `generateRepliesFromScroll` (after `userId`, line 130).

- [ ] **Step 2: Populate it from the App Group in all three bodies.** In `generateReplies` (the `ReplyRequest(...)` at line 61), `generateRepliesFromEmail` (the `ReplyEmailRequest(...)` at line 91), and `generateRepliesFromScroll` (the `ScrollRequest(...)` at line 133), add this argument after `userId: AppGroupService.shared.userID()`:

```swift
            aboutUser: AppGroupService.shared.aboutUser.isEmpty ? nil : AppGroupService.shared.aboutUser
```

- [ ] **Step 3: Build**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Shared/ReplyService.swift
git commit -m "iOS: send aboutUser on /reply, /reply/scroll, and email requests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: iOS — "About You" section in Settings

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add the `@State`.** In `struct SettingsView`, after `@State private var showTutorial = false` (line 138), add:

```swift
    @State private var aboutUser = AppGroupService.shared.aboutUser
```

- [ ] **Step 2: Place the section in the body.** In the body's `VStack` (lines 144-151), insert `aboutYouSection` right after `identityCard`:

```swift
                    identityCard
                    aboutYouSection
                    keyboardSection
```

- [ ] **Step 3: Define the section.** Add this computed property next to the other sections (e.g. just before `// MARK: - Keyboard` at line 188):

```swift
    // MARK: - About You

    private var aboutYouSection: some View {
        settingsSection("About You") {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "A few words about you — age, gender, your vibe, what you're into. Helps Replr sound like you.\ne.g. 27, guy, dry sense of humour, into climbing and techno.",
                    text: $aboutUser,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .lineLimit(3...6)
                .foregroundStyle(ReplrTheme.Color.textPrimary)
                .onChange(of: aboutUser) { newValue in
                    if newValue.count > 300 { aboutUser = String(newValue.prefix(300)) }
                    AppGroupService.shared.aboutUser = aboutUser
                }

                Text("Stays on your device — sent only to draft your replies.")
                    .font(.system(size: 12))
                    .foregroundStyle(ReplrTheme.Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
```

- [ ] **Step 4: Build**

Run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Desktop/DesktopCloud/Replr
git add Replr/Replr/Features/Settings/SettingsView.swift
git commit -m "iOS: About You section in Settings (multi-line, 300-cap, privacy note)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Verify end-to-end

**Files:** none expected (fix-ups only).

- [ ] **Step 1: Backend** — `cd /Users/WORK2/Desktop/DesktopCloud/Replr/backend && npm run typecheck && npm test -- -t buildSystemPrompt`
Expected: typecheck clean; 4 `buildSystemPrompt` tests pass.

- [ ] **Step 2: iOS build** — run the iOS build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual checks (simulator or device)**
  - Settings shows an **About You** card near the top with the placeholder; typing saves and **persists across relaunch** (`AppGroupService.aboutUser`).
  - Pasting >300 chars truncates to 300.
  - With About Me set, a live reply reads in-voice (gendered grammar correct in a gendered-language chat; dynamic right in a dating chat). With it blank, replies still generate (no regression).

- [ ] **Step 4: Deploy note (do NOT auto-deploy).** The iOS app calls the live `https://api.replr.app`. For the prompt changes to take effect end-to-end, the backend must be deployed: `cd backend && npm run deploy`. **Leave this to the user** — they trigger deploys. Until deployed, the iOS app sends `aboutUser` but the live worker ignores the unknown field harmlessly (optional), so nothing breaks pre-deploy.

- [ ] **Step 5: Commit any fix-ups (targeted, not `git add -A`).**

---

## Self-review

**Spec coverage:**
- ✅ About You field (Settings, multi-line, placeholder, 300-cap, privacy note) → Task 5
- ✅ `Constants.aboutUserKey` + `AppGroupService.aboutUser` → Task 3
- ✅ `aboutUser?` on the 3 request structs, populated from App Group, nil-when-blank → Task 4
- ✅ Backend accepts optional `aboutUser` on `/reply` + `/reply/scroll` → Task 2
- ✅ System-prompt "ABOUT THE USER" block → Task 1 (`buildSystemPrompt`)
- ✅ Recipient-gender reasoning in `DECISIONS` → Task 2
- ✅ Tests: prompt includes/omits the block (pure, isolated) → Task 1; optional end-to-end via typecheck → Task 2; iOS build + manual → Tasks 5-6
- ✅ Privacy (on-device, per-request, not server-stored) — no server persistence added; field sent with the request only

**Placeholder scan:** none — every step has concrete code/commands.

**Type/name consistency:** `aboutUser` (camelCase) is used uniformly across Swift (`AppGroupService.aboutUser`, request structs) and TS (`aboutUser?: string`, request body, `buildSystemPrompt(tone, aboutUser?)`); the App Group key string is `"about_user"`. The block marker text `ABOUT THE USER` matches between the implementation (Task 1) and the test assertions (Task 1) and the `DECISIONS` reference (Task 2).

**Known out-of-scope:** the backend suite has pre-existing failures (stale model IDs, stale `max_tokens` assertion) — not addressed here; this feature is verified via the isolated `buildSystemPrompt` run. Flag separately to the user.
