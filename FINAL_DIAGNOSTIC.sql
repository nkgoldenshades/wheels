-- ============================================
-- FINAL DIAGNOSTIC - Find the exact issue
-- ============================================

-- Test 1: Does the vehicle exist?
SELECT 
  'Test 1: Vehicle exists?' as test,
  id,
  vehicle_name,
  profile_id,
  is_online,
  is_active
FROM vehicles
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- Test 2: Does the profile exist?
SELECT 
  'Test 2: Profile exists?' as test,
  id,
  full_name,
  email
FROM profiles
WHERE id = (SELECT profile_id FROM vehicles WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787');

-- Test 3: Can we join them?
SELECT 
  'Test 3: Join works?' as test,
  v.id as vehicle_id,
  v.vehicle_name,
  v.profile_id,
  p.full_name as profile_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- Test 4: What does the RLS policy allow?
SELECT 
  'Test 4: RLS Policy' as test,
  policyname,
  cmd,
  qual as using_clause
FROM pg_policies
WHERE tablename = 'vehicles' AND cmd = 'SELECT';

-- Test 5: Can anon role see vehicles?
SET ROLE anon;
SELECT 
  'Test 5: Anon can see?' as test,
  COUNT(*) as vehicle_count
FROM vehicles;
RESET ROLE;

-- Test 6: Check foreign key name
SELECT 
  'Test 6: FK constraint name' as test,
  conname as constraint_name,
  conrelid::regclass as table_name,
  confrelid::regclass as referenced_table
FROM pg_constraint
WHERE conrelid = 'vehicles'::regclass
  AND confrelid = 'profiles'::regclass;

DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Check the results above:';
  RAISE NOTICE '1. Vehicle exists? Should show 1 row';
  RAISE NOTICE '2. Profile exists? Should show 1 row with full_name';
  RAISE NOTICE '3. Join works? Should show profile_name';
  RAISE NOTICE '4. RLS Policy? Should show USING clause';
  RAISE NOTICE '5. Anon can see? Should show count > 0';
  RAISE NOTICE '6. FK name? Should show vehicles_new_profile_id_fkey';
  RAISE NOTICE '============================================';
END $$;
