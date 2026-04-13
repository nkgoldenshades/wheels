-- ============================================
-- QUICK FIX: Posts Table RLS Policies
-- ============================================
-- Run this in Supabase SQL Editor to allow post creation
-- ============================================

-- Remove old policies
DROP POLICY IF EXISTS "public_read_posts" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;

-- Everyone can view active posts (for browsing)
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- Authenticated users can insert their own posts
CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Authenticated users can update their own posts
CREATE POLICY "users_update_own_posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Authenticated users can delete their own posts
CREATE POLICY "users_delete_own_posts"
ON public.posts
FOR DELETE
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Verify policies were created
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
