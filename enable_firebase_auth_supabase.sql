-- Enable Firebase Authentication in Supabase
-- Replace 'YOUR_FIREBASE_PROJECT_ID' with your actual Firebase Project ID

-- Step 1: Configure JWT settings for Firebase
-- You need to get your Firebase Project ID from Firebase Console

-- For now, let's allow both 'anon' and 'authenticated' roles
-- This will work with Firebase JWT once properly configured

-- Drop existing policies
DROP POLICY IF EXISTS "trip_media_select" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_update" ON storage.objects;

-- Allow public to read
CREATE POLICY "trip_media_select"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'trip_media');

-- Allow both anon and authenticated to upload
-- This works with Firebase JWT
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'trip_media');

-- Allow both anon and authenticated to update
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'trip_media');

-- Allow both anon and authenticated to delete
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO anon, authenticated
USING (bucket_id = 'trip_media');

-- Verify the policies
SELECT policyname, cmd, roles, with_check::text
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%';
