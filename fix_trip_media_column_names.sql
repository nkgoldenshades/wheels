-- Fix trip_media RLS policies - correct column names from actual database
-- Database uses: profile_customer_id and profile_provider_id

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

-- Allow authenticated users to insert if they are part of the booking
-- Path format: {bookingId}/{userId}/{phase}/{filename}
-- Check: booking exists AND user is either the customer or provider
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'trip_media' AND
  EXISTS (
    SELECT 1 FROM public.bookings
    WHERE bookings.id::text = (string_to_array(name, '/'))[1]
    AND (
      bookings.profile_customer_id = auth.jwt()->>'sub'
      OR bookings.profile_provider_id = auth.jwt()->>'sub'
    )
  )
);

-- Allow authenticated users to update their own files
-- Path segment [2] is the userId who uploaded
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.jwt()->>'sub'
);

-- Allow authenticated users to delete their own files
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.jwt()->>'sub'
);

-- Verify the policies
SELECT 
  policyname,
  cmd,
  roles,
  with_check::text as check_condition
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%'
ORDER BY policyname;
