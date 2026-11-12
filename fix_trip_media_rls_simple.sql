-- Fix Trip Media Storage RLS Policies
-- This version works with Firebase JWT or allows all authenticated users

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

-- Allow ALL authenticated users to insert (simplified for Firebase JWT)
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'trip_media');

-- Allow ALL authenticated users to update
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'trip_media');

-- Allow ALL authenticated users to delete
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'trip_media');

