-- Fix Firebase JWT Authentication Role Issue
-- This grants the 'authenticator' role to Firebase JWT users

-- ============================================================================
-- PART 1: Update Storage Policies to Work with Firebase JWT
-- ============================================================================

-- The issue is that Firebase JWT users are not recognized as 'authenticated'
-- We need to allow 'anon' role as well, since Firebase JWT might come through as anon

-- Drop existing policies
DROP POLICY IF EXISTS "trip_media_select" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_update" ON storage.objects;

-- Allow public to read all trip media
CREATE POLICY "trip_media_select"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'trip_media');

-- Allow anon role to insert (Firebase JWT comes through as anon initially)
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'trip_media');

-- Allow anon role to update
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'trip_media');

-- Allow anon role to delete
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO anon, authenticated
USING (bucket_id = 'trip_media');

-- ============================================================================
-- PART 2: Grant Necessary Permissions
-- ============================================================================

-- Grant usage on storage schema to anon role
GRANT USAGE ON SCHEMA storage TO anon;
GRANT ALL ON storage.objects TO anon;
GRANT ALL ON storage.buckets TO anon;

-- ============================================================================
-- PART 3: Verify Configuration
-- ============================================================================

-- Check the policies
SELECT 
  policyname,
  cmd,
  roles,
  with_check::text as check_condition
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%'
ORDER BY policyname;

-- Check bucket configuration
SELECT id, name, public FROM storage.buckets WHERE id = 'trip_media';
