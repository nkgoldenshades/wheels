-- ============================================
-- FIX: Allow All Users to See All Vehicles
-- ============================================
-- This fixes RLS so ALL users can see ALL vehicles
-- (needed for common feed to work)
-- ============================================

-- Step 1: Check current SELECT policy
SELECT 
  '========== CURRENT POLICY ==========' as check_type,
  policyname,
  cmd,
  roles,
  qual as using_clause
FROM pg_policies 
WHERE tablename = 'vehicles' AND cmd = 'SELECT';

-- Step 2: Drop existing SELECT policies that filter by user
DROP POLICY IF EXISTS "vehicles_select" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_select_own" ON public.vehicles;
DROP POLICY IF EXISTS "users_select_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "authenticated_select_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "select_own_vehicles" ON public.vehicles;

-- Step 3: Create new SELECT policy that allows EVERYONE to see ALL vehicles
CREATE POLICY "public_select_all_vehicles"
ON public.vehicles
FOR SELECT
TO public
USING (true);  -- Allow all users to see all vehicles

-- Step 4: Keep INSERT/UPDATE/DELETE restricted to vehicle owners
-- (These are correct - users should only modify their own vehicles)

-- Vehicles INSERT
DROP POLICY IF EXISTS "vehicles_insert" ON public.vehicles;
CREATE POLICY "vehicles_insert_own"
ON public.vehicles
FOR INSERT
TO public
WITH CHECK (
  (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL
  AND profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Vehicles UPDATE
DROP POLICY IF EXISTS "vehicles_update" ON public.vehicles;
CREATE POLICY "vehicles_update_own"
ON public.vehicles
FOR UPDATE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text)
WITH CHECK (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- Vehicles DELETE
DROP POLICY IF EXISTS "vehicles_delete" ON public.vehicles;
CREATE POLICY "vehicles_delete_own"
ON public.vehicles
FOR DELETE
TO public
USING (profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text);

-- Step 5: Verify the new policies
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
WHERE tablename = 'vehicles'
ORDER BY cmd, policyname;

-- Step 6: Test as anonymous user
SET ROLE anon;

SELECT 
  '========== TEST AS GUEST ==========' as test,
  COUNT(*) as visible_vehicles,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Guest can see vehicles'
    ELSE '❌ Guest cannot see vehicles'
  END as status
FROM vehicles;

RESET ROLE;

-- Step 7: Summary
SELECT 
  '========== SUMMARY ==========' as summary,
  (SELECT COUNT(*) FROM vehicles) as total_vehicles,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'vehicles' AND cmd = 'SELECT' AND 'public' = ANY(roles)) as public_select_policies,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'vehicles' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
    THEN '✅ Common feed enabled - all users can see all vehicles'
    ELSE '❌ Common feed NOT enabled - check policies'
  END as status;
