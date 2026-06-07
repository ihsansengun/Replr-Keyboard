# Sign in with Apple — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mandatory Sign in with Apple so every user has an account the developer can look up when handling support requests or analytics.

**Architecture:** Backend adds a Cloudflare D1 database (users + sessions tables) and a `/auth/apple` endpoint that validates Apple's identity JWT using the `jose` library, upserts a user record, and returns a 32-byte session token. iOS adds an `AuthService` that stores the token in Keychain, shows a `SignInView` (mandatory, one-time) before onboarding, and sends `Authorization: Bearer <token>` on every API call. Credits stay entirely client-side (StoreKit + UserDefaults) — no backend migration.

**Tech Stack:** Cloudflare D1 (SQLite), `jose` (JWT), Hono middleware, AuthenticationServices (iOS), Security framework (Keychain)

---

## Scope note — two sequential subsystems

Backend must be deployed before iOS can be tested end-to-end. Work through the backend tasks first (Tasks 1–6), run `npm run deploy`, then do the iOS tasks (Tasks 7–10).

---

## File Map

**New (backend):**
- `backend/migrations/0001_create_users_and_sessions.sql` — D1 schema
- `backend/src/services/auth.ts` — Apple JWT validation
- `backend/src/routes/auth.ts` — POST /auth/apple
- `backend/src/middleware/session.ts` — attach user_id from Bearer token
- `backend/tests/auth.test.ts` — unit + integration tests

**Modified (backend):**
- `backend/wrangler.toml` — add `[[d1_databases]]` binding + `jose` in `package.json`
- `backend/src/types/index.ts` — add `DB: D1Database` to `Env`, add `User`/`Session` types
- `backend/src/index.ts` — mount `authRoute`
- `backend/src/routes/reply.ts` — import and apply `sessionMiddleware`

**New (iOS):**
- `Replr/Replr/Services/AuthService.swift` — Sign in with Apple coordinator + Keychain wrapper
- `Replr/Replr/Features/Account/SignInView.swift` — mandatory sign-in screen

**Modified (iOS):**
- `Replr/Replr/App/ReplrApp.swift` — gate on sign-in before onboarding
- `Replr/Shared/ReplyService.swift` — add `Authorization` header to all requests
- `Replr/Replr/Features/Settings/SettingsView.swift` — account row (email + sign-out)

---

## Task 1: D1 database setup

**Files:**
- Create: `backend/migrations/0001_create_users_and_sessions.sql`
- Modify: `backend/wrangler.toml`

- [ ] **Step 1: Create the D1 database**

```bash
cd /Users/WORK2/Developer/Replr/backend
npx wrangler d1 create replr-db
```

Expected output (note the `database_id` — you'll need it next):
```
✅ Successfully created DB 'replr-db'
[[d1_databases]]
binding = "DB"
database_name = "replr-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

- [ ] **Step 2: Write the migration SQL**

Create `backend/migrations/0001_create_users_and_sessions.sql`:

```sql
-- Users: one row per Apple account, created on first Sign in with Apple.
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,           -- our own UUID (crypto.randomUUID())
  apple_id    TEXT UNIQUE NOT NULL,       -- Apple's stable per-app user identifier
  email       TEXT,                       -- relay or real email; NULL if user hid it
  name        TEXT,                       -- display name from Apple (first sign-in only)
  created_at  INTEGER NOT NULL            -- Unix epoch seconds
);

-- Sessions: 30-day tokens issued by /auth/apple.
CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,           -- 64-char hex (32 random bytes)
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER NOT NULL,           -- Unix epoch seconds
  created_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_user_id   ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_expires   ON sessions(expires_at);
```

- [ ] **Step 3: Apply the migration locally**

```bash
cd /Users/WORK2/Developer/Replr/backend
npx wrangler d1 migrations apply replr-db --local
```

Expected: `✅ Applied 1 migrations`

- [ ] **Step 4: Update wrangler.toml**

Add the D1 binding (replace `YOUR_DATABASE_ID` with the ID from Step 1):

```toml
[[d1_databases]]
binding = "DB"
database_name = "replr-db"
database_id = "YOUR_DATABASE_ID"
```

Full updated `wrangler.toml`:

```toml
name = "replr-api"
main = "src/index.ts"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]

[vars]
FREE_DAILY_LIMIT = "200"
SHORTCUT_INSTALL_URL = "https://www.icloud.com/shortcuts/73472454024d4a48b1d2a9108fec4bc8"

[[kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "4bdb1c9ad31f40dda0898c86b8472234"

[[d1_databases]]
binding = "DB"
database_name = "replr-db"
database_id = "YOUR_DATABASE_ID"

[[routes]]
pattern = "api.replr.app/*"
zone_name = "replr.app"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add backend/migrations/0001_create_users_and_sessions.sql backend/wrangler.toml
git commit -m "feat: add D1 database schema for users and sessions"
```

---

## Task 2: Add `jose` and update backend types

**Files:**
- Modify: `backend/package.json` (via npm install)
- Modify: `backend/src/types/index.ts`

- [ ] **Step 1: Install `jose`**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm install jose
```

Expected: `jose` added to `dependencies` in `package.json`.

- [ ] **Step 2: Write the failing typecheck**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm run typecheck
```

This will fail because `Env` doesn't have `DB` yet. Note the error — it's the signal we're fixing.

- [ ] **Step 3: Update `backend/src/types/index.ts`**

Replace the file with:

```typescript
import type { D1Database, KVNamespace } from '@cloudflare/workers-types'

export type Model =
  | 'gpt-5.4'
  | 'gpt-5.4-mini'
  | 'gpt-5.5'
  | 'claude-sonnet-4-6'
  | 'claude-opus-4-6'
  | 'claude-opus-4-7'
  | 'claude-haiku-4-5'
  | 'grok-4'
  | 'grok-4.3'
  | 'gemini-3.1-pro-preview'
  | 'gemini-3.1-pro-low'
  | 'gemini-3-flash-preview'
  | 'gemini-3.5-flash'
  | 'gemini-3.1-flash-lite'
  | 'gemini-2.5-pro'

export interface Env {
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  XAI_API_KEY: string
  GOOGLE_API_KEY: string
  FREE_DAILY_LIMIT: string
  RATE_LIMIT_KV: KVNamespace
  DB: D1Database
  SHORTCUT_INSTALL_URL?: string
}

export interface ReplyRequest {
  screenshotBase64?: string
  emailText?: string
  tone: string
  toneName?: string
  summary?: string
  previousContext?: string
  model: Model
  userId: string
}

export interface ReplyResponse {
  replies: string[]
  summary: string
  contactName: string
}

// Auth types
export interface User {
  id: string
  apple_id: string
  email: string | null
  name: string | null
  created_at: number
}

export interface Session {
  token: string
  user_id: string
  expires_at: number
  created_at: number
}

export interface AppleClaims {
  sub: string          // stable Apple user identifier
  email?: string
  email_verified?: boolean | string
}
```

- [ ] **Step 4: Verify typecheck passes**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm run typecheck
```

Expected: no errors (D1Database is now in scope).

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add backend/package.json backend/package-lock.json backend/src/types/index.ts
git commit -m "feat: add jose dependency and D1/auth types to Env"
```

---

## Task 3: Apple JWT validation service

**Files:**
- Create: `backend/src/services/auth.ts`

`jose` is Apple-JWT-ready out of the box. The flow: fetch Apple's JWKS → find the key matching the token's `kid` header → verify signature and standard claims.

- [ ] **Step 1: Write the failing test first**

Create `backend/tests/auth.test.ts` (partial — just the service shape test, full tests in Task 6):

```typescript
import { describe, it, expect } from 'vitest'
import { validateAppleToken } from '../src/services/auth'

describe('validateAppleToken', () => {
  it('rejects a malformed token', async () => {
    await expect(validateAppleToken('not-a-jwt', 'com.ihsan.replr')).rejects.toThrow()
  })
})
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm test -- tests/auth.test.ts
```

Expected: FAIL — `Cannot find module '../src/services/auth'`

- [ ] **Step 3: Create `backend/src/services/auth.ts`**

```typescript
import { importJWK, jwtVerify, type JWTPayload } from 'jose'

interface AppleJWK {
  kty: string
  kid: string
  use: string
  alg: string
  n: string
  e: string
}

export interface AppleClaims extends JWTPayload {
  sub: string
  email?: string
  email_verified?: boolean | string
}

// Fetch Apple's public JWKS (cached by the CF edge runtime for ~5 min via normal HTTP caching).
async function fetchApplePublicKeys(): Promise<AppleJWK[]> {
  const res = await fetch('https://appleid.apple.com/auth/keys', {
    cf: { cacheTtl: 300, cacheEverything: true },
  } as RequestInit)
  if (!res.ok) throw new Error(`Apple JWKS fetch failed: ${res.status}`)
  const body = await res.json() as { keys: AppleJWK[] }
  return body.keys
}

/**
 * Validates an Apple identity token (JWT) returned by Sign in with Apple on iOS.
 *
 * @param identityToken  The raw JWT string from ASAuthorizationAppleIDCredential.identityToken
 * @param audience       The app's bundle ID — e.g. "com.ihsan.replr"
 * @throws               If the token is invalid, expired, or the signature doesn't verify
 */
export async function validateAppleToken(
  identityToken: string,
  audience: string
): Promise<AppleClaims> {
  const keys = await fetchApplePublicKeys()

  // Apple rotates keys; try each until one succeeds (matched by `kid` header in the JWT).
  let lastError: unknown
  for (const jwk of keys) {
    try {
      const key = await importJWK(jwk, jwk.alg)
      const { payload } = await jwtVerify(identityToken, key, {
        issuer: 'https://appleid.apple.com',
        audience,
      })
      if (typeof payload.sub !== 'string') throw new Error('Missing sub claim')
      return payload as AppleClaims
    } catch (err) {
      lastError = err
    }
  }
  throw lastError ?? new Error('Apple token validation failed: no valid key')
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm test -- tests/auth.test.ts
```

Expected: PASS (the malformed-token test passes because `validateAppleToken` throws on bad input).

- [ ] **Step 5: Typecheck**

```bash
npm run typecheck
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add backend/src/services/auth.ts backend/tests/auth.test.ts
git commit -m "feat: add Apple JWT validation service"
```

---

## Task 4: `/auth/apple` route

**Files:**
- Create: `backend/src/routes/auth.ts`
- Modify: `backend/src/index.ts`

- [ ] **Step 1: Add route tests to `backend/tests/auth.test.ts`**

Append to the existing `auth.test.ts`:

```typescript
import { vi, beforeEach } from 'vitest'
import { app } from '../src/index'

vi.mock('../src/services/auth', () => ({
  validateAppleToken: vi.fn(),
}))

import { validateAppleToken } from '../src/services/auth'
const mockValidate = vi.mocked(validateAppleToken)

// Minimal D1 stub — returns null for SELECT (new user) and resolves for INSERT/INDEX creation.
const mockDB = {
  prepare: (sql: string) => ({
    bind: (..._args: unknown[]) => ({
      first: async () => null,
      run: async () => ({ success: true }),
    }),
  }),
}

const fakeEnv = {
  ANTHROPIC_API_KEY: 'test',
  OPENAI_API_KEY: 'test',
  RATE_LIMIT_KV: { get: async () => null, put: async () => {} },
  DB: mockDB,
  FREE_DAILY_LIMIT: '200',
}

describe('POST /auth/apple', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockValidate.mockResolvedValue({ sub: 'apple-user-123', email: 'user@example.com', iss: 'https://appleid.apple.com', aud: 'com.ihsan.replr', exp: 9999999999, iat: 1000000000 })
  })

  it('returns 400 when identityToken is missing', async () => {
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    }, fakeEnv)
    expect(res.status).toBe(400)
  })

  it('returns 401 when Apple token is invalid', async () => {
    mockValidate.mockRejectedValue(new Error('invalid'))
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken: 'bad-token' }),
    }, fakeEnv)
    expect(res.status).toBe(401)
  })

  it('returns 200 with a session token for a valid Apple token', async () => {
    const res = await app.request('/auth/apple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identityToken: 'valid-token' }),
    }, fakeEnv)
    expect(res.status).toBe(200)
    const body = await res.json() as { token: string; expiresAt: number }
    expect(typeof body.token).toBe('string')
    expect(body.token).toHaveLength(64)  // 32 bytes → 64 hex chars
    expect(typeof body.expiresAt).toBe('number')
  })
})
```

- [ ] **Step 2: Run — expect failures**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm test -- tests/auth.test.ts
```

Expected: FAIL — route not registered yet.

- [ ] **Step 3: Create `backend/src/routes/auth.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from '../types'
import { validateAppleToken } from '../services/auth'

export const authRoute = new Hono<{ Bindings: Env }>()

const APPLE_AUDIENCE = 'com.ihsan.replr'  // Must match the iOS app's bundle ID exactly
const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60  // 30 days

authRoute.post('/apple', async (c) => {
  // Parse body
  let body: Record<string, unknown>
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400)
  }

  const { identityToken, email, name } = body as {
    identityToken?: string
    email?: string
    name?: string
  }

  if (!identityToken || typeof identityToken !== 'string') {
    return c.json({ error: 'Missing identityToken' }, 400)
  }

  // Validate with Apple
  let claims: { sub: string; email?: string }
  try {
    claims = await validateAppleToken(identityToken, APPLE_AUDIENCE)
  } catch (err) {
    console.error('Apple token validation failed:', err)
    return c.json({ error: 'Invalid Apple identity token' }, 401)
  }

  const now = Math.floor(Date.now() / 1000)

  // Upsert user — Apple only sends email on first sign-in; preserve it thereafter.
  const existing = await c.env.DB
    .prepare('SELECT id, email FROM users WHERE apple_id = ?')
    .bind(claims.sub)
    .first<{ id: string; email: string | null }>()

  let userID: string
  if (existing) {
    userID = existing.id
    // Apple sent an email this time but we didn't have one — store it now.
    const incomingEmail = email ?? claims.email ?? null
    if (incomingEmail && !existing.email) {
      await c.env.DB
        .prepare('UPDATE users SET email = ? WHERE id = ?')
        .bind(incomingEmail, userID)
        .run()
    }
  } else {
    userID = crypto.randomUUID()
    const storedEmail = email ?? claims.email ?? null
    const storedName = (name && name.trim()) ? name.trim() : null
    await c.env.DB
      .prepare('INSERT INTO users (id, apple_id, email, name, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(userID, claims.sub, storedEmail, storedName, now)
      .run()
  }

  // Generate a 64-char hex session token (32 cryptographically random bytes).
  const tokenBytes = new Uint8Array(32)
  crypto.getRandomValues(tokenBytes)
  const token = Array.from(tokenBytes).map(b => b.toString(16).padStart(2, '0')).join('')
  const expiresAt = now + SESSION_TTL_SECONDS

  await c.env.DB
    .prepare('INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(token, userID, expiresAt, now)
    .run()

  return c.json({ token, expiresAt })
})
```

- [ ] **Step 4: Mount the route in `backend/src/index.ts`**

```typescript
import { Hono } from 'hono'
import { healthRoute } from './routes/health'
import { replyRoute } from './routes/reply'
import { configRoute } from './routes/config'
import { authRoute } from './routes/auth'
import type { Env } from './types'

export const app = new Hono<{ Bindings: Env }>()

app.route('/health', healthRoute)
app.route('/auth', authRoute)
app.route('/reply', replyRoute)
app.route('/config', configRoute)

export default app
```

- [ ] **Step 5: Run tests — expect pass**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm test -- tests/auth.test.ts
```

Expected: all 4 tests in the describe block PASS.

- [ ] **Step 6: Full test suite**

```bash
npm test
```

Expected: all existing tests still pass (no regressions).

- [ ] **Step 7: Typecheck**

```bash
npm run typecheck
```

Expected: no errors.

- [ ] **Step 8: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add backend/src/routes/auth.ts backend/src/index.ts backend/tests/auth.test.ts
git commit -m "feat: add /auth/apple endpoint — validates Apple JWT, creates user + session in D1"
```

---

## Task 5: Session middleware for `/reply` routes

**Files:**
- Create: `backend/src/middleware/session.ts`
- Modify: `backend/src/routes/reply.ts`

The middleware reads `Authorization: Bearer <token>`, validates it against D1 sessions, and attaches `authenticatedUserID` to the Hono context. If no token is present the request still proceeds (backward compat with anonymous `userId`). This lets the backend log the user without breaking existing anonymous clients.

- [ ] **Step 1: Create `backend/src/middleware/session.ts`**

```typescript
import type { MiddlewareHandler } from 'hono'
import type { Env } from '../types'

// Hono variable key for the authenticated user ID (set by sessionMiddleware).
export const SESSION_USER_ID_KEY = 'authenticatedUserID'

export type SessionVariables = {
  [SESSION_USER_ID_KEY]: string | undefined
}

/**
 * Reads `Authorization: Bearer <token>`, validates against the sessions table,
 * and attaches the user_id to the Hono context under SESSION_USER_ID_KEY.
 *
 * Non-blocking: missing or invalid tokens are silently ignored so existing
 * anonymous clients keep working.
 */
export const sessionMiddleware: MiddlewareHandler<{
  Bindings: Env
  Variables: SessionVariables
}> = async (c, next) => {
  const authorization = c.req.header('Authorization')
  if (authorization?.startsWith('Bearer ')) {
    const token = authorization.slice(7).trim()
    if (token.length === 64) {  // sanity-check: our tokens are always 64 hex chars
      const now = Math.floor(Date.now() / 1000)
      const session = await c.env.DB
        .prepare('SELECT user_id FROM sessions WHERE token = ? AND expires_at > ?')
        .bind(token, now)
        .first<{ user_id: string }>()
      if (session) {
        c.set(SESSION_USER_ID_KEY, session.user_id)
      }
    }
  }
  await next()
}
```

- [ ] **Step 2: Apply middleware in `backend/src/routes/reply.ts`**

Add after the imports at the top of `reply.ts`:

```typescript
import { sessionMiddleware } from '../middleware/session'

// Apply session middleware to all /reply routes (non-blocking — anonymous clients still work).
replyRoute.use('*', sessionMiddleware)
```

The full top of the file should look like:

```typescript
import { Hono } from 'hono'
import { generateReplies, generateRepliesFromEmail, generateRepliesFromMultiple } from '../services/llm'
import type { Env, Model } from '../types'
import { sessionMiddleware } from '../middleware/session'

export const replyRoute = new Hono<{ Bindings: Env }>()

replyRoute.use('*', sessionMiddleware)
```

- [ ] **Step 3: Typecheck**

```bash
cd /Users/WORK2/Developer/Replr/backend
npm run typecheck
```

Expected: no errors.

- [ ] **Step 4: Run full test suite**

```bash
npm test
```

Expected: all tests pass — existing reply tests are unaffected because the middleware no-ops when no `Authorization` header is present (the `fakeEnv` in tests has no `DB` — but the middleware only queries D1 when a Bearer token is present, so no crash).

**Note:** If existing reply tests fail because `fakeEnv` doesn't have `DB`, add `DB: undefined` to `fakeEnv` in `reply.test.ts`. The middleware guard `token.length === 64` will no-op without hitting D1.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add backend/src/middleware/session.ts backend/src/routes/reply.ts
git commit -m "feat: add session middleware — attaches authenticated user_id to /reply context"
```

---

## Task 6: Deploy backend to production

- [ ] **Step 1: Apply migration to production D1**

```bash
cd /Users/WORK2/Developer/Replr/backend
npx wrangler d1 migrations apply replr-db
```

Expected: `✅ Applied 1 migrations` against the remote database.

- [ ] **Step 2: Deploy**

```bash
npm run deploy
```

Expected: `✅ Deployed to api.replr.app`

- [ ] **Step 3: Smoke-test the endpoint**

```bash
curl -s -X POST https://api.replr.app/auth/apple \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
```

Expected:
```json
{"error":"Missing identityToken"}
```
(400 — correct; we just verified the route is live.)

- [ ] **Step 4: Commit**

No new code — the deploy is the artifact. Commit the fact that migrations are applied:

```bash
cd /Users/WORK2/Developer/Replr
git commit --allow-empty -m "chore: deploy D1 auth backend to production"
```

---

## Task 7: iOS `AuthService` + Keychain wrapper

**Files:**
- Create: `Replr/Replr/Services/AuthService.swift`

This file has two responsibilities: a minimal `Keychain` helper and the `AuthService` that coordinates Sign in with Apple + backend exchange. It lives in the main app target (`Replr`), not in `Shared/` — the keyboard extension never needs to sign in.

- [ ] **Step 1: Write the failing test**

Add to `Replr/ReplrTests/ReplrTests.swift`:

```swift
@Test func keychainRoundTrip() throws {
    let key = "test.keychain.key.\(Int.random(in: 1...999999))"
    defer { Keychain.delete(forKey: key) }
    try Keychain.save("hello-world", forKey: key)
    #expect(Keychain.load(forKey: key) == "hello-world")
    Keychain.delete(forKey: key)
    #expect(Keychain.load(forKey: key) == nil)
}
```

- [ ] **Step 2: Run — expect FAIL**

Build & test in Xcode (⌘U). Expected: `keychainRoundTrip` fails — `Keychain` type not found.

- [ ] **Step 3: Create `Replr/Replr/Services/AuthService.swift`**

```swift
import AuthenticationServices
import Foundation
import Security

// MARK: - Keychain helper

enum Keychain {
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            switch self { case .saveFailed(let s): return "Keychain save failed: \(s)" }
        }
    }

    static func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:        data,
        ]
        SecItemDelete(query as CFDictionary)  // delete any previous value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var userEmail: String?

    private enum Keys {
        static let sessionToken = "replr.auth.sessionToken"
        static let userEmail    = "replr.auth.userEmail"
        static let userName     = "replr.auth.userName"
    }

    private override init() {
        isSignedIn = Keychain.load(forKey: Keys.sessionToken) != nil
        userEmail  = Keychain.load(forKey: Keys.userEmail)
        super.init()
    }

    var sessionToken: String? { Keychain.load(forKey: Keys.sessionToken) }
    var userName: String?     { Keychain.load(forKey: Keys.userName) }

    // MARK: - Sign In

    /// Called by SignInView after a successful ASAuthorizationAppleIDCredential.
    /// Sends the Apple identity token to the backend, stores the returned session token.
    func signIn(identityToken: Data, email: String?, name: String?) async throws {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidIdentityToken
        }

        let url = URL(string: Constants.backendURL + "/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        var bodyDict: [String: String] = ["identityToken": tokenString]
        if let email { bodyDict["email"] = email }
        if let name, !name.isEmpty { bodyDict["name"] = name }
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.serverError
        }

        struct AuthResponse: Decodable { let token: String }
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)

        try Keychain.save(decoded.token, forKey: Keys.sessionToken)
        if let email { try Keychain.save(email, forKey: Keys.userEmail) }
        if let name, !name.isEmpty { try Keychain.save(name, forKey: Keys.userName) }

        isSignedIn = true
        userEmail  = email ?? Keychain.load(forKey: Keys.userEmail)
    }

    // MARK: - Sign Out

    func signOut() {
        Keychain.delete(forKey: Keys.sessionToken)
        Keychain.delete(forKey: Keys.userEmail)
        Keychain.delete(forKey: Keys.userName)
        isSignedIn = false
        userEmail  = nil
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidIdentityToken
        case serverError

        var errorDescription: String? {
            switch self {
            case .invalidIdentityToken: return "Apple sign-in failed. Please try again."
            case .serverError:          return "Couldn't connect to Replr. Check your connection and try again."
            }
        }
    }
}
```

- [ ] **Step 4: Add `AuthService.swift` to the Replr target in Xcode**

In Xcode's Project Navigator, right-click `Replr/Services/` (create the folder if it doesn't exist), choose "Add Files to Replr", and select `AuthService.swift`. Ensure only the **Replr** target is checked (not keyboard, not broadcast).

- [ ] **Step 5: Build and run tests (⌘U)**

Expected: `keychainRoundTrip` passes. All 20+ existing tests still pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add Replr/Replr/Services/AuthService.swift Replr/Replr.xcodeproj/project.pbxproj
git commit -m "feat: add AuthService with Keychain wrapper and Sign in with Apple coordinator"
```

---

## Task 8: `SignInView` + gate app on sign-in

**Files:**
- Create: `Replr/Replr/Features/Account/SignInView.swift`
- Modify: `Replr/Replr/App/ReplrApp.swift`

Before any UI work: **read `DESIGN.md`**. Use `ReplrTheme.*` for all colors, fonts, and spacing.

- [ ] **Step 1: Create `Replr/Replr/Features/Account/SignInView.swift`**

```swift
import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Called by the parent (ReplrApp) when sign-in succeeds.
    var onSuccess: () -> Void

    var body: some View {
        ZStack {
            ReplrTheme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(ReplrTheme.Color.brandGradient)

                    Text("Replr")
                        .font(ReplrTheme.Font.serif(38, weight: .bold))
                        .foregroundColor(ReplrTheme.Color.textPrimary)

                    Text("AI reply suggestions — for any conversation.")
                        .font(.system(size: 16))
                        .foregroundColor(ReplrTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Sign in area
                VStack(spacing: 14) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleResult(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                    Text("Your email is used only for account support. We don't send marketing emails.")
                        .font(.system(size: 12))
                        .foregroundColor(ReplrTheme.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 52)
            }

            if isLoading {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result else {
            // .failure — ignore user-cancel (code 1001), show message for real errors
            if case .failure(let err) = result,
               (err as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Sign in failed. Please try again."
            }
            return
        }

        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken else {
            errorMessage = "Sign in failed. Please try again."
            return
        }

        let email = credential.email
        let name: String? = {
            guard let c = credential.fullName else { return nil }
            let parts = [c.givenName, c.familyName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn(identityToken: identityToken, email: email, name: name)
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Add `SignInView.swift` to the Replr target in Xcode**

Create the `Replr/Features/Account/` folder in Xcode's Project Navigator. Add the file, checking only the **Replr** target.

- [ ] **Step 3: Gate the app on sign-in in `ReplrApp.swift`**

Find the existing state check in `ReplrApp.swift`:

```swift
@AppStorage("onboardingComplete") var onboardingComplete = false
// ...
if onboardingComplete { /* main app */ } else { OnboardingView(...) }
```

Add `@StateObject var authService = AuthService.shared` at the top of the body, and prepend a sign-in gate:

```swift
// Add to the struct's properties:
@StateObject private var authService = AuthService.shared
@State private var signedIn: Bool = AuthService.shared.isSignedIn

// Replace the top-level content gate with:
if !signedIn {
    SignInView(onSuccess: { signedIn = true })
        .environmentObject(authService)
} else if !onboardingComplete {
    OnboardingView(onComplete: { onboardingComplete = true })
} else {
    // existing main app content
}
```

**Important:** `@State private var signedIn` starts from `AuthService.shared.isSignedIn` (Keychain check at launch), so returning users who are already signed in see zero friction — the sign-in screen is skipped entirely.

- [ ] **Step 4: Build and run on simulator**

- Launch the app — `SignInView` appears (no Keychain token yet).
- The `SignInWithAppleButton` is present. Tapping it on simulator will prompt Apple sign-in.
- On a real device, Face ID / Touch ID fires; on simulator you'll see a test sheet.
- After sign-in succeeds, the app proceeds to onboarding or main screen.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add Replr/Replr/Features/Account/SignInView.swift Replr/Replr/App/ReplrApp.swift Replr/Replr.xcodeproj/project.pbxproj
git commit -m "feat: add SignInView and gate app on Sign in with Apple"
```

---

## Task 9: Pass auth token in all API requests

**Files:**
- Modify: `Replr/Shared/ReplyService.swift`

All four network methods (`generateReplies`, `generateRepliesFromEmail`, `testModel`, `generateRepliesFromScroll`) build a `URLRequest`. Add a single helper that injects the `Authorization` header when a session token is available.

- [ ] **Step 1: Add the header helper to `ReplyService`**

In `ReplyService.swift`, add this private extension method alongside `compressForUpload`:

```swift
private func addAuthHeader(to request: inout URLRequest) {
    if let token = AuthService.shared.sessionToken {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
```

- [ ] **Step 2: Call it in every method that builds a `URLRequest`**

In each of the four methods, immediately after `request.setValue("application/json", forHTTPHeaderField: "Content-Type")`, add:

```swift
addAuthHeader(to: &request)
```

The four locations are:
1. `generateReplies` — around line 87
2. `generateRepliesFromEmail` — around line 119
3. `testModel` — around line 143
4. `generateRepliesFromScroll` — around line 198

- [ ] **Step 3: Build — verify no compile errors**

```bash
cd /Users/WORK2/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build \
  2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add Replr/Shared/ReplyService.swift
git commit -m "feat: send Authorization: Bearer token on all API requests"
```

---

## Task 10: Account section in Settings

**Files:**
- Modify: `Replr/Replr/Features/Settings/SettingsView.swift`

Show the signed-in email and a sign-out button in the existing "Account" section.

- [ ] **Step 1: Find the existing account section**

In `SettingsView.swift`, find:

```swift
private var accountSection: some View {
    settingsSection("Account") {
        NavigationLink(destination: CreditPacksView()) {
```

- [ ] **Step 2: Add account info row above the Credits row**

```swift
private var accountSection: some View {
    settingsSection("Account") {
        // Signed-in identity
        if let email = AuthService.shared.userEmail {
            settingsRow {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(ReplrTheme.Color.accent)
                    .frame(width: 28)
                Text(email)
                    .font(.system(size: 15))
                    .foregroundColor(ReplrTheme.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }

        // Sign out
        Button {
            AuthService.shared.signOut()
            // ReplrApp observes authService.isSignedIn and will re-show SignInView.
        } label: {
            settingsRow {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                    .frame(width: 28)
                Text("Sign out")
                    .font(.system(size: 17))
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(.plain)

        // Existing credits row
        NavigationLink(destination: CreditPacksView()) {
```

**Note:** `AuthService.shared.signOut()` clears the Keychain token. `ReplrApp` reads `signedIn` from `@State private var signedIn: Bool = AuthService.shared.isSignedIn`. For the UI to update, `signedIn` needs to re-evaluate. Add an `.onChange` in `ReplrApp.swift`:

```swift
.onChange(of: authService.isSignedIn) { _, newValue in
    if !newValue { signedIn = false }
}
```

- [ ] **Step 3: Build and run on simulator**

- Navigate to Settings → Account section.
- Signed-in email is displayed.
- Tap "Sign out" → app returns to `SignInView`.

- [ ] **Step 4: Full build + tests**

```bash
cd /Users/WORK2/Developer/Replr/Replr
xcodebuild -project Replr.xcodeproj -scheme Replr \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test \
  2>&1 | grep -E "passed|failed" | tail -5
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/WORK2/Developer/Replr
git add Replr/Replr/Features/Settings/SettingsView.swift Replr/Replr/App/ReplrApp.swift
git commit -m "feat: show account email and sign-out button in Settings"
```

---

## Self-Review

### 1. Spec coverage

| Requirement | Task |
|---|---|
| D1 schema (users + sessions) | Task 1 |
| Apple JWT validation | Task 3 |
| `/auth/apple` endpoint | Task 4 |
| Session middleware | Task 5 |
| Deploy | Task 6 |
| Keychain session storage | Task 7 |
| Sign in with Apple UI | Task 8 |
| Mandatory sign-in gate | Task 8 |
| Auth header on API calls | Task 9 |
| Settings account section + sign-out | Task 10 |
| Credits stay client-side (no migration) | Architecture decision — no task needed |

All requirements covered.

### 2. Placeholder scan

No TBDs, TODOs, or "implement later" found. All code blocks are complete.

### 3. Type consistency

- `AppleClaims.sub: string` — used consistently in `validateAppleToken` return and `authRoute` (`claims.sub`)
- `AuthService.sessionToken: String?` — referenced in `ReplyService.addAuthHeader`
- `Keychain.save/load/delete` — used in `AuthService` and tested in `keychainRoundTrip`
- `AuthService.shared.signOut()` in SettingsView — matches the method defined in Task 7
- `AuthService.shared.isSignedIn` observed via `.onChange` in ReplrApp — matches `@Published private(set) var isSignedIn` in Task 7
