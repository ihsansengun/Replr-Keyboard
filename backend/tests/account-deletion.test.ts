import { describe, it, expect } from 'vitest'
import { app } from '../src/index'
import { makeTestEnv, TEST_SESSION_TOKEN, TEST_USER_ID } from './helpers'

// App Review 5.1.1(v): apps with account creation must offer in-app account
// deletion. DELETE /auth/account wipes the user and every row keyed to them.
describe('DELETE /auth/account', () => {
  function deleteRequest(auth: boolean) {
    const headers: Record<string, string> = {}
    if (auth) headers['Authorization'] = `Bearer ${TEST_SESSION_TOKEN}`
    return { method: 'DELETE', headers }
  }

  it('returns 401 without a session', async () => {
    const { env } = makeTestEnv()
    const res = await app.request('/auth/account', deleteRequest(false), env)
    expect(res.status).toBe(401)
  })

  it('deletes every table keyed to the user in one atomic batch', async () => {
    const { env, db } = makeTestEnv({}, { balance: 250 })
    const res = await app.request('/auth/account', deleteRequest(true), env)
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ ok: true })

    expect(db.batch).toHaveBeenCalledTimes(1)
    const stmts = db.batch.mock.calls[0][0] as Array<{ _sql: string; _args: unknown[] }>
    const tables = ['credit_ledger', 'credits', 'paywall_events', 'sessions', 'users']
    for (const table of tables) {
      const stmt = stmts.find(s => s._sql.includes(`DELETE FROM ${table}`))
      expect(stmt, `missing DELETE FROM ${table}`).toBeDefined()
      expect(stmt!._args).toEqual([TEST_USER_ID])
    }
    expect(stmts).toHaveLength(tables.length)
  })

  it('invalidates the session: authed requests fail afterwards', async () => {
    const { env } = makeTestEnv({}, { balance: 100 })

    const del = await app.request('/auth/account', deleteRequest(true), env)
    expect(del.status).toBe(200)

    // The same token must no longer resolve — balance is gated behind sign-in.
    const after = await app.request('/credits', {
      headers: { Authorization: `Bearer ${TEST_SESSION_TOKEN}` },
    }, env)
    expect(after.status).toBe(401)

    // And a second delete with the dead token is a 401, not a silent re-wipe.
    const again = await app.request('/auth/account', deleteRequest(true), env)
    expect(again.status).toBe(401)
  })
})
