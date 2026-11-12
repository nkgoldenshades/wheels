-- ============================================================================
-- TEMPORARY FIX: Disable RLS on post_media entirely (for testing)
-- WARNING: This makes uploads public - only use for debugging/testing
-- ============================================================================

-- 1. Create/ensure bucket exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post_media',
  'post_media',
  true,
  10737418240,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'video/quicktime']::text[]
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop all post_media policies
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

-- 3. Create PERMISSIVE policies (no restrictions for testing)
CREATE POLICY "post_media_allow_all_select"
ON storage.objects FOR SELECT
TO public, authenticated, anon
USING (bucket_id = 'post_media');

CREATE POLICY "post_media_allow_all_insert"
ON storage.objects FOR INSERT
TO public, authenticated, anon
WITH CHECK (bucket_id = 'post_media');

CREATE POLICY "post_media_allow_all_update"
ON storage.objects FOR UPDATE
TO public, authenticated, anon
USING (bucket_id = 'post_media')
WITH CHECK (bucket_id = 'post_media');

CREATE POLICY "post_media_allow_all_delete"
ON storage.objects FOR DELETE
TO public, authenticated, anon
USING (bucket_id = 'post_media');

-- 4. Verify
SELECT 
  policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname ILIKE '%post_media%';

-- ============================================================================
-- RESULT: All users can upload/read/delete from post_media (test mode)
-- After testing works, apply fix_post_media_policies_clean.sql for security
-- ============================================================================
