-- Fix vehicle_media storage bucket policies for image upload

-- Step 1: Check if bucket exists
SELECT 
  name, 
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets 
WHERE name = 'vehicle_media';

-- If bucket doesn't exist, create it (uncomment if needed):
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('vehicle_media', 'vehicle_media', true)
-- ON CONFLICT (id) DO NOTHING;

-- Step 2: Drop existing policies (to recreate them correctly)
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload to own folder" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to update own files" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete own files" ON storage.objects;

-- Step 3: Create correct policies for vehicle_media bucket

-- Policy 1: Public read access (anyone can view images)
CREATE POLICY "Public read access for vehicle_media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'vehicle_media');

-- Policy 2: Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload to own folder in vehicle_media"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (
  bucket_id = 'vehicle_media' 
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- Policy 3: Allow users to update their own files
CREATE POLICY "Users can update own files in vehicle_media"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (
  bucket_id = 'vehicle_media' 
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
)
WITH CHECK (
  bucket_id = 'vehicle_media' 
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- Policy 4: Allow users to delete their own files
CREATE POLICY "Users can delete own files in vehicle_media"
ON storage.objects FOR DELETE
TO authenticated, anon
USING (
  bucket_id = 'vehicle_media' 
  AND (storage.foldername(name))[1] = auth.jwt()->>'sub'
);

-- Step 4: Verify policies are created
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%vehicle_media%';

-- Step 5: Test upload permissions (check if current user can upload)
SELECT 
  'Current user: ' || COALESCE(auth.jwt()->>'sub', 'NOT AUTHENTICATED') as user_check;

-- Step 6: Show bucket configuration
SELECT 
  'Bucket Configuration' as info,
  name,
  public as is_public,
  CASE 
    WHEN public THEN '✅ Public (images accessible via URL)'
    ELSE '⚠️ Private (images need signed URLs)'
  END as status
FROM storage.buckets 
WHERE name = 'vehicle_media';
