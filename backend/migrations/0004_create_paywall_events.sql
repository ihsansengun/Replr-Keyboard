-- Paywall A/B telemetry: one row per impression (client-reported, variant
-- computed server-side) and per first-time purchase (recorded inside
-- /credits/redeem). Analysis is a GROUP BY over (experiment, variant, event).
CREATE TABLE IF NOT EXISTS paywall_events (
  id          TEXT PRIMARY KEY,            -- crypto.randomUUID()
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  experiment  TEXT NOT NULL,
  variant     TEXT NOT NULL,
  event       TEXT NOT NULL,               -- 'impression' | 'purchase'
  product_id  TEXT,                        -- purchases only
  created_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS paywall_events_exp ON paywall_events(experiment, variant, event);
