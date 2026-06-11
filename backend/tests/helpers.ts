import { vi } from 'vitest'
import type { Env } from '../src/types'

/** Token the fake sessions table recognises; resolves to TEST_USER_ID. */
export const TEST_SESSION_TOKEN = 'a'.repeat(64)
export const TEST_USER_ID = 'user-1'

export interface FakeState {
  /** KV contents, keyed by full KV key (`rate:<key>:<YYYY-MM-DD>`). */
  kv: Map<string, string>
  /** credits.balance for TEST_USER_ID; null = no credits row (not server-managed). */
  balance: number | null
  /** credit_ledger.ref values already present (StoreKit dedup). */
  ledgerRefs: Set<string>
  /** users.is_dev for TEST_USER_ID (server-side test exemption). */
  isDev: boolean
  /** paywall_events rows captured by the fake DB. */
  paywallEvents: Array<{ userId: string; experiment: string; variant: string; event: string; productId: string | null }>
  /** True once a batch containing DELETE FROM users ran — session lookups then fail. */
  deleted: boolean
}

export function todayKey(key: string): string {
  return `rate:${key}:${new Date().toISOString().split('T')[0]}`
}

/** Stateful fakes for KV + D1 covering the queries the routes actually run:
 *  sessions lookup, credits balance SELECT, trySpend conditional UPDATE, and
 *  grant() batches (ledger INSERT + balance upsert, UNIQUE-on-ref semantics). */
export function makeTestEnv(overrides: Partial<Env> = {}, init?: Partial<FakeState>) {
  const state: FakeState = {
    kv: new Map(Object.entries(init?.kv ?? {})),
    balance: init?.balance ?? null,
    ledgerRefs: new Set(init?.ledgerRefs ?? []),
    isDev: init?.isDev ?? false,
    paywallEvents: init?.paywallEvents ?? [],
    deleted: init?.deleted ?? false,
  }
  if (init?.kv instanceof Map) state.kv = init.kv

  const kv = {
    get: vi.fn(async (key: string) => state.kv.get(key) ?? null),
    put: vi.fn(async (key: string, value: string) => { state.kv.set(key, value) }),
    delete: vi.fn(),
    list: vi.fn(),
    getWithMetadata: vi.fn(),
  }

  const prepare = (sql: string) => ({
    bind: (...args: unknown[]) => ({
      _sql: sql,
      _args: args,
      async first() {
        if (sql.includes('FROM sessions')) {
          return args[0] === TEST_SESSION_TOKEN && !state.deleted ? { user_id: TEST_USER_ID } : null
        }
        if (sql.includes('FROM users u LEFT JOIN credits')) {
          // getAccessProfile: one row per existing user; balance NULL without a credits row.
          return args[0] === TEST_USER_ID
            ? { balance: state.balance, is_dev: state.isDev ? 1 : 0 }
            : null
        }
        if (sql.includes('SELECT balance FROM credits')) {
          return state.balance === null ? null : { balance: state.balance }
        }
        if (sql.startsWith('UPDATE credits SET balance = balance -')) {
          const cost = args[1] as number
          if (state.balance === null || state.balance < cost) return null
          state.balance -= cost
          return { balance: state.balance }
        }
        return null
      },
      async run() {
        if (sql.includes('INSERT INTO paywall_events')) {
          state.paywallEvents.push({
            userId: args[1] as string,
            experiment: args[2] as string,
            variant: args[3] as string,
            event: args[4] as string,
            productId: (args.length > 6 ? args[5] : null) as string | null,
          })
        }
        return { success: true, meta: { changes: 1 } }
      },
    }),
  })

  const db = {
    prepare,
    batch: vi.fn(async (stmts: Array<{ _sql: string; _args: unknown[] }>) => {
      if (stmts.some(s => s._sql.includes('DELETE FROM users'))) {
        state.deleted = true
      }
      const ledgerInsert = stmts.find(s => s._sql.includes('INSERT INTO credit_ledger'))
      if (ledgerInsert) {
        const ref = ledgerInsert._args[4] as string | null
        if (ref !== null && state.ledgerRefs.has(ref)) {
          throw new Error('UNIQUE constraint failed: credit_ledger.ref')
        }
        if (ref !== null) state.ledgerRefs.add(ref)
        const upsert = stmts.find(s => s._sql.includes('INSERT INTO credits'))
        if (upsert) {
          const delta = upsert._args[1] as number
          state.balance = (state.balance ?? 0) + delta
        }
      }
      return stmts.map(() => ({ success: true }))
    }),
  }

  const env = {
    ANTHROPIC_API_KEY: 'test-key',
    OPENAI_API_KEY: 'test-key',
    XAI_API_KEY: 'test-key',
    GOOGLE_API_KEY: 'test-key',
    FREE_DAILY_LIMIT: '200',
    ANON_DAILY_LIMIT: '50',
    REQUIRE_AUTH: 'false',
    ALLOW_SANDBOX_TRANSACTIONS: 'true',
    RATE_LIMIT_KV: kv,
    DB: db,
    ...overrides,
  } as unknown as Env

  return { env, state, kv, db }
}

/** Standard JSON POST with optional Bearer auth. */
export function jsonRequest(body: unknown, opts: { auth?: boolean; ip?: string } = {}) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (opts.auth) headers['Authorization'] = `Bearer ${TEST_SESSION_TOKEN}`
  if (opts.ip) headers['CF-Connecting-IP'] = opts.ip
  return { method: 'POST', headers, body: JSON.stringify(body) }
}
