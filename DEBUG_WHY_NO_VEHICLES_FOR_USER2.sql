-- ============================================
-- DEBUG: Why User 2 Can't See Vehicles
-- ============================================

-- Step 1: Check all vehicles in database
SELECT 
  '1. ALL VEHICLES IN DATABASE' as info,
  id,
  profile_id,
  vehicle_name,
  vehicle_type,
  created_at
FROM vehicles
ORDER BY created_at DESC;

-- Step 2: Check RLS policies on vehicles table
SELECT 
  '2. VEHICLES RLS POLICIES' as info,
  policyname,
  cmd,
  roles,
  qual as using_clause,
  with_check
FROM pg_policies 
WHERE tablename = 'vehicles'
ORDER BY cmd, policyname;

-- Step 3: Check if RLS is enabled
SELECT 
  '3. RLS STATUS' as info,
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'vehicles';

-- Step 4: Test as anonymous user (guest)
SET ROLE anon;

SELECT 
  '4. WHAT GUEST SEES' as info,
  COUNT(*) as visible_vehicles
FROM vehicles;

SELECT 
  '4. GUEST VEHICLE DETAILS' as info,
  id,
  vehicle_name,
  profile_id
FROM vehicles
LIMIT 5;

RESET ROLE;

-- Step 5: Diagnosis
SELECT 
  '========== DIAGNOSIS ==========' as diagnosis,
  (SELECT COUNT(*) FROM vehicles) as total_vehicles,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'vehicles' AND cmd = 'SELECT') as select_policies,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'vehicles' AND cmd = 'SELECT' AND qual LIKE '%profile_id%') > 0
    THEN '❌ PROBLEM: SELECT policy filters by profile_id - users only see own vehicles'
    WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'vehicles' AND cmd = 'SELECT' AND 'public' = ANY(roles)) > 0
    THEN '✅ OK: SELECT policy allows all users to see all vehicles'
    ELSE '⚠️ WARNING: No SELECT policy found or restrictive policy'
  END as vehicles_policy_status;

-- Step 6: Show the actual SELECT policy
SELECT 
  '6. ACTUAL SELECT POLICY' as info,
  policyname,
  qual as using_clause,
  'If this contains profile_id, that is the problem!' as note
FROM pg_policies 
WHERE tablename = 'vehicles' AND cmd = 'SELECT';
