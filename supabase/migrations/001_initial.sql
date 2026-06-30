-- Vidflow Supabase schema
-- Run via: supabase db push (or paste in SQL editor)

-- Profiles
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Creator',
  avatar_url TEXT,
  videos_generated INT NOT NULL DEFAULT 0,
  videos_downloaded INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Generated videos (3-day retention)
CREATE TABLE IF NOT EXISTS generated_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'expired')),
  thumbnail_url TEXT,
  video_url TEXT,
  storage_path TEXT,
  duration_seconds INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '3 days')
);

CREATE INDEX IF NOT EXISTS idx_generated_videos_user
  ON generated_videos(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_generated_videos_expires
  ON generated_videos(expires_at);

ALTER TABLE generated_videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own videos"
  ON generated_videos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own videos"
  ON generated_videos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own videos"
  ON generated_videos FOR UPDATE
  USING (auth.uid() = user_id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', 'Creator'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Cleanup expired videos (run via pg_cron or scheduled Edge Function)
CREATE OR REPLACE FUNCTION cleanup_expired_videos()
RETURNS void AS $$
BEGIN
  UPDATE generated_videos
  SET status = 'expired'
  WHERE expires_at <= NOW() AND status != 'expired';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Storage bucket (create in dashboard or via API)
-- Bucket name: generated-videos
-- Public: false (use signed URLs in production)
-- File size limit: 100MB
-- Allowed MIME: video/mp4
