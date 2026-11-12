-- ============================================
-- CHECK WHAT DIFFERENT USERS SEE
-- ============================================
-- This shows what posts each user can see based on RLS
-- ============================================

-- 1. Show all posts in database (as admin)
SELECT 
  '1. ALL POSTS IN DATABASE (Admin View)' as info,
  id,
  profile_id,
  service_type,
  from_location,
  to_location,
  is_active,
  created_at
FROM posts
ORDER BY created_at DESC;

-- 2. Show all user_posts in database (as admin)
SELECT 
  '2. ALL USER_POSTS IN DATABASE (Admin View)' as info,
  id,
  profile_id,
  service_type,
  from_location,
  to_location,
  is_active,
  created_at
FROM user_posts
ORDER BY created_at DESC;

-- 3. Check current RLS policies
SELECT 
  '3. CURRENT RLS POLICIES' as info,
  tablename,
  policyname,
  cmd,
  roles,
  qual as using_clause
FROM pg_policies 
WHERE tablename IN ('posts', 'user_posts')
ORDER BY tablename, cmd, policyname;

-- 4. Simulate what an anonymous user sees
SET ROLE anon;

SELECT 
  '4. WHAT GUEST SEES (anon role)' as info,
  COUNT(*) as visible_posts
FROM posts 
WHERE is_active = true;

SELECT 
  '4. WHAT GUEST SEES (anon role) - user_posts' as info,
  COUNT(*) as visible_user_posts
FROM user_posts 
WHERE is_active = true;

RESET ROLE;

-- 5. Check if RLS is enabled
SELECT 
  '5. RLS STATUS' as info,
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity = true THEN '✅ RLS is enabled'
    ELSE '⚠️ RLS is disabled'
  END as status
FROM pg_tables 
WHERE tablename IN ('posts', 'user_posts');

-- 6. Show which users have posts
SELECT 
  '6. USERS WITH POSTS' as info,
  p.profile_id,
  pr.full_name,
  COUNT(*) as post_count
FROM posts p
LEFT JOIN profiles pr ON pr.id = p.profile_id
WHERE p.is_active = true
GROUP BY p.profile_id, pr.full_name
ORDER BY post_count DESC;

-- 7. Show which users have user_posts
SELECT 
  '7. USERS WITH USER_POSTS' as info,
  up.profile_id,
  pr.full_name,
  COUNT(*) as post_count
FROM user_posts up
LEFT JOIN profiles pr ON pr.id = up.profile_id
WHERE up.is_active = true
GROUP BY up.profile_id, pr.full_name
ORDER BY post_count DESC;

-- 8. Diagnosis
SELECT 
  '========== DIAGNOSIS ==========' as diagnosis,
  (SELECT COUNT(*) FROM posts WHERE is_active = true) as total_active_posts,
  (SELECT COUNT(*) FROM user_posts WHERE is_active = true) as total_active_user_posts,
  (SELECT COUNT(DISTINCT profile_id) FROM posts WHERE is_active = true) as unique_post_creators,
  (SELECT COUNT(DISTINCT profile_id) FROM user_posts WHERE is_active = true) as unique_user_post_creators,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'posts' AND cmd = 'SELECT' AND qual LIKE '%profile_id%') > 0
    THEN '❌ PROBLEM: SELECT policy filters by profile_id - users only see own posts'
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
    THEN '✅ OK: SELECT policy allows all users to see all posts'
    ELSE '⚠️ WARNING: No SELECT policy found'
  END as posts_policy_status,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_posts' AND cmd = 'SELECT' AND qual LIKE '%profile_id%') > 0
    THEN '❌ PROBLEM: SELECT policy filters by profile_id - users only see own posts'
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_posts' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
    THEN '✅ OK: SELECT policy allows all users to see all posts'
    ELSE '⚠️ WARNING: No SELECT policy found'
  END as user_posts_policy_status;
