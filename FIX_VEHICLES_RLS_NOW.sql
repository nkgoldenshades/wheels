-- ============================================
-- FIX VEHICLES RLS - IMMEDIATE FIX
-- ============================================
-- This replaces the insecure policy with a secure one
-- Run this in Supabase SQL Editor NOW
-- ============================================

-- Step 1: Drop the insecure policy
DROP POLICY IF EXISTS "public_read_vehicles" ON public.vehicles;

-- Step 2: Create secure policies

-- Guests can view ONLINE vehicles only (for browsing)
CREATE POLICY "guests_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO anon
USING (is_online = true);

-- Authenticated users can view:
-- 1. Their own vehicles (all of them)
-- 2. Other users' ONLINE vehicles (for browsing)
CREATE POLICY "users_view_vehicles"
ON public.vehicles
FOR SELECT
TO authenticated
USING (
  profile_id = auth.jwt()->>'sub'  -- Own vehicles
  OR is_online = true              -- Others' online vehicles
);

-- Step 3: Verify the fix
SELECT 
  policyname,
  cmd,
  roles::text,
  CASE 
    WHEN qual LIKE '%profile_id%' THEN 'Filters by owner'
    WHEN qual LIKE '%is_online%' THEN 'Filters by online status'
    ELSE 'Other condition'
  END as security_level
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- ============================================
-- EXPECTED RESULT:
-- ============================================
/*
After running this, you should see:

policyname                    | cmd    | roles           | security_level
------------------------------|--------|-----------------|------------------
guests_view_online_vehicles   | SELECT | {anon}          | Filters by online status
users_view_vehicles           | SELECT | {authenticated} | Filters by owner
vehicles_delete               | DELETE | {anon,authenticated} | (existing)
vehicles_insert               | INSERT | {authenticated} | (existing)
vehicles_update               | UPDATE | {authenticated} | (existing)

✅ Now:
- Guests see only ONLINE vehicles
- Users see their own vehicles + others' online vehicles
- Users CANNOT see other users' offline vehicles
*/

-- ============================================
-- TEST QUERIES
-- ============================================

-- Test 1: Count vehicles by visibility
SELECT 
  'Total vehicles' as category,
  COUNT(*) as count
FROM vehicles
UNION ALL
SELECT 
  'Online vehicles' as category,
  COUNT(*) as count
FROM vehicles
WHERE is_online = true
UNION ALL
SELECT 
  'Offline vehicles' as category,
  COUNT(*) as count
FROM vehicles
WHERE is_online = false OR is_online IS NULL;

-- Test 2: Check if any vehicles have NULL profile_id (data issue)
SELECT 
  COUNT(*) as vehicles_without_owner
FROM vehicles
WHERE profile_id IS NULL OR profile_id = '';

-- If this returns > 0, you have data issues that need fixing
