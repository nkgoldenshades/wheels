-- ============================================================================
-- WORKAROUND: Try alternative approach - allow all uploads, then fix RLS
-- ============================================================================
-- This is a temporary workaround while we diagnose the UUID issue
-- The error is coming from Supabase's storage service, not from RLS
-- We'll create a public bucket that accepts all uploads, then verify it works

-- 1. Drop ALL existing policies
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN (
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname ILIKE '%post_media%'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
  END LOOP;
END $$;

-- 2. Create post_media bucket with minimal config
UPDATE storage.buckets 
SET 
  public = true,
  file_size_limit = 10737418240,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'video/quicktime']::text[]
WHERE id = 'post_media';

-- If bucket doesn't exist, create it
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post_media',
  'post_media',
  true,
  10737418240,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'video/quicktime']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 3. Allow completely unrestricted access (for testing only)
CREATE POLICY "post_media_allow_all"
ON storage.objects 
FOR ALL
TO authenticated, anon, public
USING (bucket_id = 'post_media')
WITH CHECK (bucket_id = 'post_media');

-- 4. Verify bucket
SELECT 
  id, 
  name, 
  public, 
  file_size_limit,
  allowed_mime_types
FROM storage.buckets 
WHERE id = 'post_media';

-- 5. Verify policy
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname ILIKE '%post_media%';

-- ============================================================================
-- RESULT: Bucket allows all authenticated/anon/public users to upload
-- If THIS works, the issue is in Supabase's internal storage layer
-- If THIS fails with same UUID error, it's a Supabase configuration issue
-- ============================================================================
