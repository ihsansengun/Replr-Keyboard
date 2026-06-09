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
