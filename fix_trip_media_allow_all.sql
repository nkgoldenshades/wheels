-- TEMPORARY: Allow ALL access to trip_media (for testing only)
-- This will help us confirm if the issue is authentication

-- Drop existing policies
DROP POLICY IF EXISTS "trip_media_select" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_update" ON storage.objects;

-- Allow ANYONE (public/anon) to do everything
CREATE POLICY "trip_media_select"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'trip_media');

CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'trip_media');

CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'trip_media');

CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'trip_media');

-- Verify policies were created
SELECT policyname, cmd, roles 
FROM pg_policies 
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%';
