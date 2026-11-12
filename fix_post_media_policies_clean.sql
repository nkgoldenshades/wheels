-- ============================================================================
-- CLEAN FIX: Remove ALL policies and recreate for post_media bucket
-- ============================================================================

-- 1. DISABLE RLS temporarily to clear all policies
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL policies for post_media bucket (use CASCADE)
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

-- 3. RE-ENABLE RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 4. Verify bucket exists and is public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post_media',
  'post_media',
  true,
  10737418240,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'video/quicktime']::text[]
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 5. CREATE NEW POLICIES (clean slate)

-- Policy 1: Public SELECT (allow any role to read/download)
CREATE POLICY "post_media_public_select"
ON storage.objects FOR SELECT
TO public, authenticated, anon
USING (bucket_id = 'post_media');

-- Policy 2: Authenticated INSERT (Firebase JWT users only)
-- Path: {userId}/posts/{postId}/{timestamp}_{filename}
CREATE POLICY "post_media_authenticated_insert"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- Policy 3: Authenticated UPDATE
CREATE POLICY "post_media_authenticated_update"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
)
WITH CHECK (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- Policy 4: Authenticated DELETE
CREATE POLICY "post_media_authenticated_delete"
ON storage.objects FOR DELETE
TO authenticated, anon
USING (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- 6. Verify all policies were created
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname ILIKE '%post_media%'
ORDER BY policyname;

-- 7. Verify bucket config
SELECT id, name, public FROM storage.buckets WHERE id = 'post_media';

-- ============================================================================
-- DONE: All post_media policies have been reset and recreated
-- ============================================================================
