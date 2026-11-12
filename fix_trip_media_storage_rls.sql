-- Fix Trip Media Storage RLS Policy
-- This allows authenticated users to upload trip media for their bookings

-- 1. Ensure the trip_media bucket is public
UPDATE storage.buckets SET public = true WHERE id = 'trip_media';

-- 2. Drop ALL existing policies for trip_media bucket
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' 
        AND policyname LIKE '%trip_media%'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
    END LOOP;
END $$;

-- 3. Create new RLS policies for trip_media bucket

-- Allow authenticated users to upload files to their own path
-- Path format: {bookingId}/{userId}/{phase}/{filename}
CREATE POLICY "Allow authenticated uploads to trip_media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'trip_media' AND
  -- Extract userId from path (second segment)
  (string_to_array(name, '/'))[2] = auth.uid()::text
);

-- Allow authenticated users to update their own files
CREATE POLICY "Allow authenticated updates to trip_media"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
);

-- Allow public read access to all trip media (since bucket is public)
CREATE POLICY "Allow public read access to trip_media"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'trip_media');

-- Allow authenticated users to delete their own files
CREATE POLICY "Allow authenticated deletes from trip_media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
);

-- 4. Verify the policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%';
