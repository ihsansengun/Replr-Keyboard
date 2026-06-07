-- Users: one row per Apple account, created on first Sign in with Apple.
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  apple_id    TEXT UNIQUE NOT NULL,
  email       TEXT,
  name        TEXT,
  created_at  INTEGER NOT NULL
);

-- Sessions: 30-day tokens issued by /auth/apple.
CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER NOT NULL,
  created_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_user_id   ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_expires   ON sessions(expires_at);
