import type { D1Database } from '@cloudflare/workers-types'

interface BalanceRow { balance: number }

/** Current balance, or null when the user has no credits row yet — i.e. the
 *  server does not manage this user's credits (legacy client-side era). */
export async function getBalance(db: D1Database, userId: string): Promise<number | null> {
  const row = await db
    .prepare('SELECT balance FROM credits WHERE user_id = ?')
    .bind(userId)
    .first<BalanceRow>()
  return row ? row.balance : null
}

/** Grants credits atomically: ledger INSERT + balance upsert in one D1 batch
 *  (implicit transaction). When `ref` is set and a ledger row with that ref
 *  already exists, the UNIQUE constraint rejects the whole batch → returns the
 *  existing balance with granted=false. This is the StoreKit double-redeem guard. */
export async function grant(
  db: D1Database,
  userId: string,
  delta: number,
  reason: 'purchase' | 'migration' | 'refund',
  ref: string | null
): Promise<{ balance: number; granted: boolean }> {
  const now = Math.floor(Date.now() / 1000)
  try {
    await db.batch([
      db.prepare('INSERT INTO credit_ledger (id, user_id, delta, reason, ref, created_at) VALUES (?, ?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), userId, delta, reason, ref, now),
      db.prepare('INSERT INTO credits (user_id, balance, created_at) VALUES (?1, ?2, ?3) ON CONFLICT(user_id) DO UPDATE SET balance = balance + ?2')
        .bind(userId, delta, now),
    ])
    return { balance: (await getBalance(db, userId)) ?? delta, granted: true }
  } catch (err) {
    if (ref !== null && String(err).includes('UNIQUE')) {
      return { balance: (await getBalance(db, userId)) ?? 0, granted: false }
    }
    throw err
  }
}

/** Conditionally spends `cost` credits in a single atomic statement. Returns the
 *  new balance, or null when the user has no credits row or an insufficient
 *  balance. The follow-up ledger row is best-effort audit trail — the balance
 *  itself is the source of truth. */
export async function trySpend(db: D1Database, userId: string, cost: number): Promise<number | null> {
  const row = await db
    .prepare('UPDATE credits SET balance = balance - ?2 WHERE user_id = ?1 AND balance >= ?2 RETURNING balance')
    .bind(userId, cost)
    .first<BalanceRow>()
  if (!row) return null
  const now = Math.floor(Date.now() / 1000)
  await db
    .prepare('INSERT INTO credit_ledger (id, user_id, delta, reason, ref, created_at) VALUES (?, ?, ?, ?, NULL, ?)')
    .bind(crypto.randomUUID(), userId, -cost, 'spend', now)
    .run()
  return row.balance
}
