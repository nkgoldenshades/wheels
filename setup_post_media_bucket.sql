-- ============================================================================
-- SETUP: post_media Storage policies (Firebase JWT with text sub)
-- Using string_to_array() pattern (proven working with trip_media)
-- ============================================================================
-- IMPORTANT: Uses auth.jwt()->>'sub' (text) instead of auth.uid() (UUID)
-- This prevents "invalid input syntax for type uuid" errors with Firebase UIDs
-- ============================================================================

-- 1. Ensure bucket exists and is public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post_media',
  'post_media',
  true,
  10737418240, -- 10 GB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'video/quicktime']::text[]
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop old policies (if they exist)
DROP POLICY IF EXISTS "post_media_public_select" ON storage.objects;
DROP POLICY IF EXISTS "post_media_authenticated_insert" ON storage.objects;
DROP POLICY IF EXISTS "post_media_authenticated_update" ON storage.objects;
DROP POLICY IF EXISTS "post_media_authenticated_delete" ON storage.objects;
DROP POLICY IF EXISTS "post_media_allow_all_select" ON storage.objects;
DROP POLICY IF EXISTS "post_media_allow_all_insert" ON storage.objects;
DROP POLICY IF EXISTS "post_media_allow_all_update" ON storage.objects;
DROP POLICY IF EXISTS "post_media_allow_all_delete" ON storage.objects;
DROP POLICY IF EXISTS "post_media select - public" ON storage.objects;
DROP POLICY IF EXISTS "post_media upload - owner" ON storage.objects;
DROP POLICY IF EXISTS "post_media update - owner" ON storage.objects;
DROP POLICY IF EXISTS "post_media delete - owner" ON storage.objects;

-- 3. Policy 1: Public SELECT (anyone can download via public URL)
CREATE POLICY "post_media_select"
ON storage.objects FOR SELECT
TO public, authenticated, anon
USING (bucket_id = 'post_media');

-- 4. Policy 2: INSERT - Firebase JWT users only (authenticated/anon)
-- Path format: {userId}/posts/{postId}/{timestamp}_{filename}
-- Extract userId from first path segment and compare to Firebase UID
-- Uses string_to_array() like the working trip_media policies
CREATE POLICY "post_media_insert"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (
  bucket_id = 'post_media'
  AND (string_to_array(name, '/'))[1] = (auth.jwt() ->> 'sub')
);

-- 5. Policy 3: UPDATE - Firebase JWT users only
CREATE POLICY "post_media_update"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (
  bucket_id = 'post_media'
  AND (string_to_array(name, '/'))[1] = (auth.jwt() ->> 'sub')
)
WITH CHECK (
  bucket_id = 'post_media'
  AND (string_to_array(name, '/'))[1] = (auth.jwt() ->> 'sub')
);

-- 6. Policy 4: DELETE - Firebase JWT users only
CREATE POLICY "post_media_delete"
ON storage.objects FOR DELETE
TO authenticated, anon
USING (
  bucket_id = 'post_media'
  AND (string_to_array(name, '/'))[1] = (auth.jwt() ->> 'sub')
);

-- 7. Verify policies
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

-- 8. Verify bucket
SELECT id, name, public FROM storage.buckets WHERE id = 'post_media';

-- ============================================================================
-- NOTES:
-- - Uses string_to_array(name, '/') like working trip_media policies
-- - First segment [1] is {userId} which matches auth.jwt()->>'sub'
-- - Path format: {userId}/posts/{postId}/{timestamp}_{filename}
-- - auth.jwt()->>'sub' extracts Firebase UID as text (not UUID)
-- - Same pattern as trip_media (which works correctly)
-- ============================================================================
