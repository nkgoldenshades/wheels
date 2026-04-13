-- ============================================
-- TEMPORARY FIX: Allow Post Creation Without JWT Validation
-- ============================================
-- WARNING: This is less secure but will let you test
-- Use this only for development/testing
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "users_insert_own_posts" ON public.posts;
DROP POLICY IF EXISTS "public_view_active_posts" ON public.posts;
DROP POLICY IF EXISTS "users_update_own_posts" ON public.posts;
DROP POLICY IF EXISTS "users_delete_own_posts" ON public.posts;

-- Allow anyone to view active posts
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- TEMPORARY: Allow insert if profile exists (no JWT check)
CREATE POLICY "allow_insert_with_valid_profile"
ON public.posts
FOR INSERT
TO public
WITH CHECK (
  -- Just check that profile_id exists in profiles table
  EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
);

-- TEMPORARY: Allow update if profile exists
CREATE POLICY "allow_update_with_valid_profile"
ON public.posts
FOR UPDATE
TO public
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
);

-- TEMPORARY: Allow delete if profile exists
CREATE POLICY "allow_delete_with_valid_profile"
ON public.posts
FOR DELETE
TO public
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
);

-- Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE tablename = 'posts'
ORDER BY policyname;

-- ============================================
-- NOTE: This is TEMPORARY for testing
-- Once you fix Firebase JWT validation, replace with:
-- 
-- CREATE POLICY "users_insert_own_posts"
-- ON public.posts
-- FOR INSERT
-- TO authenticated
-- WITH CHECK (profile_id = auth.jwt()->>'sub');
-- ============================================
