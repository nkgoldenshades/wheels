-- ============================================
-- DIAGNOSTIC: Why Posts Are Not Showing
-- ============================================
-- Run this in Supabase SQL Editor to find the problem
-- ============================================

-- 1. Do posts exist at all?
SELECT 
  '1. POSTS EXIST?' as check_name,
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE is_active = true) as active_posts,
  COUNT(*) FILTER (WHERE is_deleted = true) as deleted_posts,
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ NO POSTS IN DATABASE - Create posts first!'
    WHEN COUNT(*) FILTER (WHERE is_active = true) = 0 THEN '❌ NO ACTIVE POSTS - Set is_active = true'
    ELSE '✅ Posts exist'
  END as diagnosis
FROM posts;

-- 2. Show sample posts data
SELECT 
  '2. SAMPLE POSTS' as check_name,
  id,
  profile_id,
  vehicle_id,
  service_type,
  from_location,
  to_location,
  is_active,
  is_deleted,
  created_at
FROM posts
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check RLS policies on posts table
SELECT 
  '3. RLS POLICIES' as check_name,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies 
WHERE tablename = 'posts';

-- 4. Is RLS enabled on posts table?
SELECT 
  '4. RLS ENABLED?' as check_name,
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity = true THEN '✅ RLS is enabled'
    ELSE '⚠️ RLS is disabled (not recommended)'
  END as diagnosis
FROM pg_tables 
WHERE tablename = 'posts';

-- 5. Check if SELECT policy exists for public/anon
SELECT 
  '5. PUBLIC SELECT POLICY?' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'posts' 
      AND cmd = 'SELECT'
      AND ('public' = ANY(roles) OR 'anon' = ANY(roles))
    ) THEN '✅ Public can SELECT posts'
    ELSE '❌ NO PUBLIC SELECT POLICY - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
  END as diagnosis;

-- 6. Check if vehicles exist for posts
SELECT 
  '6. VEHICLES FOR POSTS?' as check_name,
  COUNT(DISTINCT p.id) as total_posts,
  COUNT(DISTINCT v.id) as posts_with_vehicles,
  COUNT(DISTINCT p.id) - COUNT(DISTINCT v.id) as posts_without_vehicles,
  CASE 
    WHEN COUNT(DISTINCT p.id) - COUNT(DISTINCT v.id) > 0 
    THEN '⚠️ Some posts have missing vehicles'
    ELSE '✅ All posts have vehicles'
  END as diagnosis
FROM posts p
LEFT JOIN vehicles v ON v.id = p.vehicle_id
WHERE p.is_active = true;

-- 7. Check if profiles exist for posts
SELECT 
  '7. PROFILES FOR POSTS?' as check_name,
  COUNT(DISTINCT p.id) as total_posts,
  COUNT(DISTINCT pr.id) as posts_with_profiles,
  COUNT(DISTINCT p.id) - COUNT(DISTINCT pr.id) as posts_without_profiles,
  CASE 
    WHEN COUNT(DISTINCT p.id) - COUNT(DISTINCT pr.id) > 0 
    THEN '⚠️ Some posts have missing profiles'
    ELSE '✅ All posts have profiles'
  END as diagnosis
FROM posts p
LEFT JOIN profiles pr ON pr.id = p.profile_id
WHERE p.is_active = true;

-- 8. Test SELECT as anonymous user (simulates guest browsing)
-- This shows what a guest would see
SELECT 
  '8. WHAT GUESTS SEE' as check_name,
  'Run this query as anon user to test' as instruction;

-- To test as anon, run this in a new query:
-- SET ROLE anon;
-- SELECT * FROM posts WHERE is_active = true LIMIT 5;
-- RESET ROLE;

-- 9. Check for problematic trigger
SELECT 
  '9. BLOCKING TRIGGER?' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'validate_posts_profile_matches_vehicle'
    ) THEN '❌ BLOCKING TRIGGER EXISTS - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
    ELSE '✅ No blocking trigger'
  END as diagnosis;

-- 10. Check Firebase auth helper function
SELECT 
  '10. FIREBASE HELPER?' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'is_firebase_authenticated'
    ) THEN '✅ Firebase helper exists'
    ELSE '❌ Firebase helper missing - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
  END as diagnosis;

-- 11. List posts that should be visible
SELECT 
  '11. POSTS THAT SHOULD BE VISIBLE' as info,
  p.id,
  p.profile_id,
  pr.full_name as owner_name,
  p.vehicle_id,
  v.vehicle_name,
  p.service_type,
  p.from_location,
  p.to_location,
  p.is_active,
  p.created_at
FROM posts p
LEFT JOIN profiles pr ON pr.id = p.profile_id
LEFT JOIN vehicles v ON v.id = p.vehicle_id
WHERE p.is_active = true 
  AND (p.is_deleted = false OR p.is_deleted IS NULL)
ORDER BY p.created_at DESC
LIMIT 10;

-- 12. FINAL DIAGNOSIS
SELECT 
  '========== FINAL DIAGNOSIS ==========' as summary,
  CASE 
    WHEN (SELECT COUNT(*) FROM posts WHERE is_active = true) = 0 
    THEN '❌ PROBLEM: No active posts in database'
    WHEN NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'posts' 
      AND cmd = 'SELECT'
      AND ('public' = ANY(roles) OR 'anon' = ANY(roles))
    ) THEN '❌ PROBLEM: No public SELECT policy - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
    WHEN EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'validate_posts_profile_matches_vehicle'
    ) THEN '❌ PROBLEM: Blocking trigger exists - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
    ELSE '✅ Database looks OK - Check Flutter app logs'
  END as diagnosis,
  (SELECT COUNT(*) FROM posts WHERE is_active = true) as active_posts_count,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'posts' AND cmd = 'SELECT') as select_policies_count;

-- ============================================
-- QUICK FIXES
-- ============================================

-- If no posts exist, create a test post:
-- (Replace YOUR_PROFILE_ID and YOUR_VEHICLE_ID with real IDs)
/*
INSERT INTO posts (
  id, profile_id, vehicle_id, service_type, slot_type,
  from_location, to_location, start_time, end_time,
  price, capacity, is_active, created_at
) VALUES (
  gen_random_uuid(),
  'YOUR_PROFILE_ID',
  'YOUR_VEHICLE_ID',
  'ride',
  'from_to',
  'Chennai Central',
  'Bangalore City',
  NOW() + INTERVAL '1 hour',
  NOW() + INTERVAL '5 hours',
  500,
  4,
  true,
  NOW()
);
*/

-- If posts exist but is_active = false, activate them:
/*
UPDATE posts SET is_active = true WHERE is_active = false;
*/

-- If RLS policies are wrong, run this:
/*
-- Copy and run COMPLETE_RLS_FIX_FOR_FIREBASE.sql
*/
