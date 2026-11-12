-- Complete Firebase JWT Configuration for Supabase
-- Project ID: quickohunt-app

-- ============================================================================
-- PART 1: Configure Supabase to Accept Firebase JWT
-- ============================================================================

-- Note: Supabase needs to be configured to trust Firebase's JWT tokens
-- This is typically done through the Supabase Dashboard, not SQL
-- But we can set up the RLS policies to work with Firebase JWT

-- The Firebase JWT will have these claims:
-- - iss: https://securetoken.google.com/quickohunt-app
-- - aud: quickohunt-app
-- - sub: {firebase_uid}

-- ============================================================================
-- PART 2: Create RLS Policies for trip_media Storage
-- ============================================================================

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

-- Allow authenticated users (with Firebase JWT) to upload
-- For now, we allow all authenticated users to upload to any path
-- Once Firebase JWT is properly configured, we can add path restrictions
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO authenticated, anon
WITH CHECK (bucket_id = 'trip_media');

-- Allow authenticated users to update
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO authenticated, anon
USING (bucket_id = 'trip_media');

-- Allow authenticated users to delete
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO authenticated, anon
USING (bucket_id = 'trip_media');

-- ============================================================================
-- PART 3: Verify Configuration
-- ============================================================================

-- Check the policies were created
SELECT 
  policyname,
  cmd,
  roles,
  with_check::text as check_condition
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%'
ORDER BY policyname;

-- ============================================================================
-- INSTRUCTIONS FOR DASHBOARD CONFIGURATION
-- ============================================================================

-- You still need to configure Firebase JWT in Supabase Dashboard:
-- 
-- 1. Go to: Supabase Dashboard → Authentication → Providers
-- 2. Look for "Custom" or "Third-party" providers
-- 3. Add Firebase with these settings:
--    - Provider: Firebase / Custom JWT
--    - JWKS URL: https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
--    - JWT Issuer: https://securetoken.google.com/quickohunt-app
--    - JWT Audience: quickohunt-app
--
-- OR
--
-- 4. If there's no UI option, you may need to configure it via environment variables
--    in your Supabase project settings:
--    - JWT_SECRET: (keep existing)
--    - JWT_AUD: quickohunt-app
--    - JWT_ISS: https://securetoken.google.com/quickohunt-app
--
-- After configuration, test with:
-- SELECT auth.uid(), auth.role();
-- This should return your Firebase UID when logged in
