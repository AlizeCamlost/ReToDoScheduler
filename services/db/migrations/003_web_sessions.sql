CREATE TABLE IF NOT EXISTS web_sessions (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,
  device_name TEXT NOT NULL,
  user_agent TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_web_sessions_expires_at
  ON web_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_web_sessions_last_seen_at
  ON web_sessions(last_seen_at DESC);
