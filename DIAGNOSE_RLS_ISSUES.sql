-- ============================================
-- DIAGNOSTIC SCRIPT: Check RLS Configuration
-- ============================================
-- Run this in Supabase SQL Editor to diagnose issues
-- ============================================

-- 1. Check if problematic trigger still exists
SELECT 
  'TRIGGER CHECK' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'validate_posts_profile_matches_vehicle'
    ) 
    THEN '❌ PROBLEM: Trigger still exists - run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
    ELSE '✅ OK: Trigger removed'
  END as status;

-- 2. Check if helper function exists
SELECT 
  'HELPER FUNCTION CHECK' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_proc 
      WHERE proname = 'is_firebase_authenticated'
    ) 
    THEN '✅ OK: Helper function exists'
    ELSE '❌ PROBLEM: Helper function missing - run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
  END as status;

-- 3. Check posts table RLS policies
SELECT 
  'POSTS RLS POLICIES' as check_type,
  policyname,
  cmd as command,
  roles,
  CASE 
    WHEN 'public' = ANY(roles) THEN '✅ Allows guests'
    WHEN 'anon' = ANY(roles) THEN '✅ Allows guests'
    ELSE '❌ Blocks guests'
  END as guest_access
FROM pg_policies 
WHERE tablename = 'posts'
ORDER BY policyname;

-- 4. Check vehicles table RLS policies
SELECT 
  'VEHICLES RLS POLICIES' as check_type,
  policyname,
  cmd as command,
  roles,
  CASE 
    WHEN 'public' = ANY(roles) THEN '✅ Allows guests'
    WHEN 'anon' = ANY(roles) THEN '✅ Allows guests'
    ELSE '❌ Blocks guests'
  END as guest_access
FROM pg_policies 
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- 5. Check if posts exist and are active
SELECT 
  'POSTS DATA CHECK' as check_type,
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE is_active = true) as active_posts,
  COUNT(*) FILTER (WHERE is_deleted = true) as deleted_posts,
  CASE 
    WHEN COUNT(*) FILTER (WHERE is_active = true) > 0 
    THEN '✅ OK: Active posts exist'
    ELSE '⚠️ WARNING: No active posts - create some posts'
  END as status
FROM posts;

-- 6. Check if vehicles exist and are online
SELECT 
  'VEHICLES DATA CHECK' as check_type,
  COUNT(*) as total_vehicles,
  COUNT(*) FILTER (WHERE is_online = true) as online_vehicles,
  CASE 
    WHEN COUNT(*) FILTER (WHERE is_online = true) > 0 
    THEN '✅ OK: Online vehicles exist'
    ELSE '⚠️ WARNING: No online vehicles - create some vehicles'
  END as status
FROM vehicles;

-- 7. Check if profiles exist
SELECT 
  'PROFILES DATA CHECK' as check_type,
  COUNT(*) as total_profiles,
  CASE 
    WHEN COUNT(*) > 0 
    THEN '✅ OK: Profiles exist'
    ELSE '⚠️ WARNING: No profiles - users need to sign up'
  END as status
FROM profiles;

-- 8. Check vehicle ownership (posts vs vehicles profile_id match)
SELECT 
  'VEHICLE OWNERSHIP CHECK' as check_type,
  COUNT(*) as total_posts,
  COUNT(*) FILTER (
    WHERE EXISTS (
      SELECT 1 FROM vehicles v 
      WHERE v.id = posts.vehicle_id 
      AND v.profile_id = posts.profile_id
    )
  ) as posts_with_matching_vehicles,
  COUNT(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1 FROM vehicles v 
      WHERE v.id = posts.vehicle_id 
      AND v.profile_id = posts.profile_id
    )
  ) as posts_with_mismatched_vehicles,
  CASE 
    WHEN COUNT(*) FILTER (
      WHERE NOT EXISTS (
        SELECT 1 FROM vehicles v 
        WHERE v.id = posts.vehicle_id 
        AND v.profile_id = posts.profile_id
      )
    ) > 0 
    THEN '⚠️ WARNING: Some posts have vehicle ownership mismatch'
    ELSE '✅ OK: All posts have matching vehicle ownership'
  END as status
FROM posts
WHERE is_active = true;

-- 9. List posts with vehicle ownership issues (if any)
SELECT 
  'MISMATCHED POSTS' as issue_type,
  p.id as post_id,
  p.profile_id as post_owner,
  p.vehicle_id,
  v.profile_id as vehicle_owner,
  '❌ Vehicle does not belong to post owner' as problem
FROM posts p
LEFT JOIN vehicles v ON v.id = p.vehicle_id
WHERE p.is_active = true
  AND (v.id IS NULL OR v.profile_id != p.profile_id)
LIMIT 10;

-- 10. Summary
SELECT 
  '========== SUMMARY ==========' as summary,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'validate_posts_profile_matches_vehicle')
      AND EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_firebase_authenticated')
      AND EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'posts' AND 'public' = ANY(roles))
      AND EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vehicles' AND 'public' = ANY(roles))
    THEN '✅ RLS CONFIGURATION IS CORRECT'
    ELSE '❌ RLS CONFIGURATION HAS ISSUES - Run COMPLETE_RLS_FIX_FOR_FIREBASE.sql'
  END as rls_status,
  CASE 
    WHEN (SELECT COUNT(*) FROM posts WHERE is_active = true) > 0 
    THEN '✅ Posts exist'
    ELSE '⚠️ No active posts'
  END as posts_status,
  CASE 
    WHEN (SELECT COUNT(*) FROM vehicles WHERE is_online = true) > 0 
    THEN '✅ Vehicles exist'
    ELSE '⚠️ No online vehicles'
  END as vehicles_status;
