-- Turso edge metadata schema
-- Run: turso db shell <your-db> < turso/schema.sql

CREATE TABLE IF NOT EXISTS video_cache (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  prompt TEXT NOT NULL,
  status TEXT NOT NULL,
  thumbnail_url TEXT,
  video_url TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  synced_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_video_cache_user
  ON video_cache(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS prompt_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  prompt TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_prompt_history_user
  ON prompt_history(user_id, created_at DESC);
