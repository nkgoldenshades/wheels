-- ============================================
-- ENABLE FIREBASE JWT VALIDATION IN SUPABASE
-- ============================================
-- This configures Supabase to accept Firebase JWTs
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Create a function to extract Firebase UID from JWT
CREATE OR REPLACE FUNCTION auth.firebase_uid() 
RETURNS TEXT AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'sub',
    current_setting('request.jwt.claim.sub', true)
  )::text;
$$ LANGUAGE SQL STABLE;

-- Step 2: Create a function to check if user is authenticated via Firebase
CREATE OR REPLACE FUNCTION auth.is_firebase_authenticated() 
RETURNS BOOLEAN AS $$
  SELECT auth.firebase_uid() IS NOT NULL;
$$ LANGUAGE SQL STABLE;

-- Step 3: Update posts RLS policies to use Firebase JWT
DROP POLICY IF EXISTS "public_view_active_posts" ON public.posts;
DROP POLICY IF EXISTS "users_insert_own_posts" ON public.posts;
DROP POLICY IF EXISTS "users_update_own_posts" ON public.posts;
DROP POLICY IF EXISTS "users_delete_own_posts" ON public.posts;

-- Everyone can view active posts
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- Users can insert their own posts (using Firebase UID)
CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO public
WITH CHECK (
  profile_id = auth.firebase_uid()
);

-- Users can update their own posts
CREATE POLICY "users_update_own_posts"
ON public.posts
FOR UPDATE
TO public
USING (profile_id = auth.firebase_uid())
WITH CHECK (profile_id = auth.firebase_uid());

-- Users can delete their own posts
CREATE POLICY "users_delete_own_posts"
ON public.posts
FOR DELETE
TO public
USING (profile_id = auth.firebase_uid());

-- Step 4: Test the function
-- This should return your Firebase UID when you make a request
SELECT auth.firebase_uid() as my_firebase_uid;

-- Step 5: Verify policies
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
WHERE tablename = 'posts'
ORDER BY policyname;

-- ============================================
-- IMPORTANT: You also need to configure Supabase Dashboard
-- ============================================
-- 1. Go to Supabase Dashboard → Settings → API
-- 2. Under "JWT Settings", add your Firebase project's public key
-- 3. Firebase public keys are at:
--    https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
-- 
-- OR use the simpler approach below (Option B)
-- ============================================
