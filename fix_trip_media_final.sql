-- Final fix for trip_media RLS policies
-- Allow both 'authenticated' and 'anon' roles since Firebase JWT may come through as either

-- Drop existing trip_media policies
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

-- Allow both authenticated and anon to insert
-- This works with Firebase JWT which may be recognized as either role
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO authenticated, anon
WITH CHECK (
  bucket_id = 'trip_media' AND
  EXISTS (
    SELECT 1 FROM public.bookings
    WHERE bookings.id::text = (string_to_array(name, '/'))[1]
    AND (
      bookings.profile_customer_id = (string_to_array(name, '/'))[2]
      OR bookings.profile_provider_id = (string_to_array(name, '/'))[2]
    )
  )
);

-- Allow both authenticated and anon to update their own files
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO authenticated, anon
USING (bucket_id = 'trip_media');

-- Allow both authenticated and anon to delete their own files
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO authenticated, anon
USING (bucket_id = 'trip_media');

-- Verify the policies
SELECT 
  policyname,
  cmd,
  roles,
  with_check::text as check_condition
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%'
ORDER BY policyname;
