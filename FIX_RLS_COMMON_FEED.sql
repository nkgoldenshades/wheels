-- ============================================
-- FIX RLS POLICIES FOR COMMON FEED
-- ============================================
-- This fixes RLS policies so ALL users can see ALL posts
-- ============================================

-- Step 1: Check current RLS policies on posts table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as using_clause
FROM pg_policies 
WHERE tablename IN ('posts', 'user_posts')
ORDER BY tablename, policyname;

-- Step 2: Drop existing SELECT policies that might be filtering by user
DROP POLICY IF EXISTS "posts_select" ON public.posts;
DROP POLICY IF EXISTS "posts_select_own" ON public.posts;
DROP POLICY IF EXISTS "posts_select_user" ON public.posts;
DROP POLICY IF EXISTS "users_select_own_posts" ON public.posts;
DROP POLICY IF EXISTS "authenticated_select_posts" ON public.posts;

-- Step 3: Create new SELECT policy that allows EVERYONE to see ALL active posts
CREATE POLICY "public_select_all_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true);

-- Step 4: Fix user_posts table (customer requests)
DROP POLICY IF EXISTS "user_posts_select" ON public.user_posts;
DROP POLICY IF EXISTS "user_posts_select_own" ON public.user_posts;
DROP POLICY IF EXISTS "users_select_own_user_posts" ON public.user_posts;

CREATE POLICY "public_select_all_active_user_posts"
ON public.user_posts
FOR SELECT
TO public
USING (is_active = true);

-- Step 5: Keep INSERT/UPDATE/DELETE policies restricted to own posts
-- (These are correct - users should only modify their own posts)

-- Posts table INSERT
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
CREATE POLICY "posts_insert_own"
ON public.posts
FOR INSERT
TO public
WITH CHECK (
  (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL
  AND profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Posts table UPDATE
DROP POLICY IF EXISTS "posts_update" ON public.posts;
CREATE POLICY "posts_update_own"
ON public.posts
FOR UPDATE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text)
WITH CHECK (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- Posts table DELETE
DROP POLICY IF EXISTS "posts_delete" ON public.posts;
CREATE POLICY "posts_delete_own"
ON public.posts
FOR DELETE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- User_posts table INSERT
DROP POLICY IF EXISTS "user_posts_insert" ON public.user_posts;
CREATE POLICY "user_posts_insert_own"
ON public.user_posts
FOR INSERT
TO public
WITH CHECK (
  (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL
  AND profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- User_posts table UPDATE
DROP POLICY IF EXISTS "user_posts_update" ON public.user_posts;
CREATE POLICY "user_posts_update_own"
ON public.user_posts
FOR UPDATE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text)
WITH CHECK (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- User_posts table DELETE
DROP POLICY IF EXISTS "user_posts_delete" ON public.user_posts;
CREATE POLICY "user_posts_delete_own"
ON public.user_posts
FOR DELETE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- Step 6: Verify the new policies
SELECT 
  '========== VERIFICATION ==========' as check_type,
  tablename,
  policyname,
  cmd,
  roles,
  CASE 
    WHEN cmd = 'SELECT' AND 'public' = ANY(roles) THEN '✅ Allows all users to SELECT'
    WHEN cmd = 'SELECT' THEN '❌ SELECT is restricted'
    WHEN cmd IN ('INSERT', 'UPDATE', 'DELETE') THEN '✅ Write operations restricted to owner'
    ELSE '⚠️ Unknown policy type'
  END as status
FROM pg_policies 
WHERE tablename IN ('posts', 'user_posts')
ORDER BY tablename, cmd, policyname;

-- Step 7: Test as anonymous user (simulates guest browsing)
-- Run this to verify guests can see posts
/*
SET ROLE anon;
SELECT COUNT(*) as visible_posts FROM posts WHERE is_active = true;
SELECT COUNT(*) as visible_user_posts FROM user_posts WHERE is_active = true;
RESET ROLE;
*/

-- Step 8: Summary
SELECT 
  '========== SUMMARY ==========' as summary,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) as posts_select_policies,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) as user_posts_select_policies,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
      AND (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
    THEN '✅ Common feed enabled - all users can see all posts'
    ELSE '❌ Common feed NOT enabled - check policies'
  END as status;
