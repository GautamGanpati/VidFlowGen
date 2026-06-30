-- Run once in Supabase Dashboard → SQL Editor
-- Creates the public bucket Runway needs for start-frame images.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'prompt-images',
  'prompt-images',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "Anyone can read prompt images" ON storage.objects;
CREATE POLICY "Anyone can read prompt images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'prompt-images');

DROP POLICY IF EXISTS "Anyone can upload prompt images" ON storage.objects;
CREATE POLICY "Anyone can upload prompt images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'prompt-images');

DROP POLICY IF EXISTS "Anyone can update prompt images" ON storage.objects;
CREATE POLICY "Anyone can update prompt images"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'prompt-images');
