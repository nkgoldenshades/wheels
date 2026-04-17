-- ============================================
-- DIAGNOSE: Why profiles is NULL
-- ============================================
-- Run this in Supabase SQL Editor

-- ============================================
-- TEST 1: Check if vehicles have valid profile_id
-- ============================================
SELECT 
    v.id as vehicle_id,
    v.vehicle_name,
    v.profile_id,
    p.id as profile_exists,
    p.full_name,
    p.email,
    CASE 
        WHEN p.id IS NULL THEN '❌ Profile does not exist'
        WHEN p.full_name IS NULL OR p.full_name = '' THEN '⚠️ Profile exists but no name'
        ELSE '✅ Profile has name'
    END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
ORDER BY v.created_at DESC
LIMIT 10;

-- Expected: All rows should show '✅ Profile has name'
-- If '❌ Profile does not exist': vehicle.profile_id doesn't match any profile
-- If '⚠️ Profile exists but no name': profile.full_name is NULL

-- ============================================
-- TEST 2: Check RLS policies on profiles table
-- ============================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual::text as condition
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Expected: Should have a SELECT policy that allows anon/authenticated to read
-- If no SELECT policy: RLS is blocking reads
-- If SELECT policy has auth.uid() = id: Guest users can't read profiles

-- ============================================
-- TEST 3: Check if RLS is enabled on profiles
-- ============================================
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'profiles';

-- Expected: rls_enabled = true
-- If false: RLS is disabled (profiles should be readable)

-- ============================================
-- INTERPRETATION
-- ============================================

/*
SCENARIO A: TEST 1 shows '❌ Profile does not exist'
→ Problem: vehicle.profile_id doesn't match any profile.id
→ Fix: Update vehicle.profile_id to match existing profile, or create missing profile

SCENARIO B: TEST 1 shows '⚠️ Profile exists but no name'
→ Problem: profile.full_name is NULL or empty
→ Fix: Update profiles to add full_name

SCENARIO C: TEST 2 shows policy with auth.uid() = id
→ Problem: Guest users (anon role) can't read profiles
→ Fix: Add permissive SELECT policy for anon role

SCENARIO D: TEST 2 shows no SELECT policy
→ Problem: RLS is blocking all reads
→ Fix: Add SELECT policy
*/

-- ============================================
-- FIX A: Update profiles without names
-- ============================================

-- First, check which profiles need names:
SELECT 
    id,
    email,
    full_name,
    CASE 
        WHEN full_name IS NULL OR full_name = '' THEN 'NEEDS UPDATE'
        ELSE 'OK'
    END as status
FROM profiles
ORDER BY created_at DESC;

-- If any show 'NEEDS UPDATE', run this:
-- UPDATE profiles
-- SET full_name = COALESCE(
--     NULLIF(full_name, ''),
--     email,
--     'User ' || substring(id, 1, 8)
-- )
-- WHERE full_name IS NULL OR full_name = '';

-- ============================================
-- FIX B: Add permissive RLS policy for profiles
-- ============================================

-- Drop existing restrictive policies
-- DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
-- DROP POLICY IF EXISTS "Profiles are viewable by authenticated users only" ON profiles;

-- Create permissive policy for all users (including anon)
-- CREATE POLICY "Allow all to read profiles"
-- ON profiles
-- FOR SELECT
-- TO authenticated, anon
-- USING (true);

-- Verify policy was created:
-- SELECT policyname, cmd, qual::text
-- FROM pg_policies
-- WHERE tablename = 'profiles' AND cmd = 'SELECT';

-- ============================================
-- FIX C: Create missing profiles
-- ============================================

-- Find vehicles with missing profiles:
SELECT 
    v.id as vehicle_id,
    v.profile_id,
    'Missing profile' as issue
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE p.id IS NULL;

-- If any found, you need to either:
-- 1. Create the missing profile
-- 2. Update vehicle.profile_id to point to existing profile

-- ============================================
-- FINAL VERIFICATION
-- ============================================

-- After running fixes, this should return all vehicles with names:
SELECT 
    v.id,
    v.vehicle_name,
    p.full_name as owner_name,
    v.is_online,
    CASE 
        WHEN p.full_name IS NOT NULL AND p.full_name != '' THEN '✅ HAS NAME'
        ELSE '❌ NO NAME'
    END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
ORDER BY v.created_at DESC
LIMIT 10;

-- ✅ All rows should show '✅ HAS NAME'
