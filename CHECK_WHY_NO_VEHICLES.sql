-- ============================================
-- DIAGNOSE: Why VehicleRepository has 0 vehicles
-- ============================================

-- Test 1: Does vehicles_public view exist?
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'vehicles_public';

-- Expected: 1 row with table_type = 'VIEW'
-- If empty: View doesn't exist, need to create it

-- ============================================

-- Test 2: Does vehicles table have data?
SELECT COUNT(*) as total_vehicles FROM vehicles;

-- Expected: > 0
-- If 0: No vehicles in database

-- ============================================

-- Test 3: Does vehicles_public view return data?
SELECT COUNT(*) as vehicles_in_view FROM vehicles_public;

-- Expected: > 0
-- If 0: RLS blocking or view definition wrong

-- ============================================

-- Test 4: Show actual data from vehicles table
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_active,
  created_at
FROM vehicles
ORDER BY created_at DESC
LIMIT 5;

-- ============================================

-- Test 5: Try to query vehicles_public view
SELECT 
  id,
  vehicle_name,
  profile_name,  -- This should exist if view is correct
  profile_id,
  is_active
FROM vehicles_public
ORDER BY created_at DESC
LIMIT 5;

-- If error "column profile_name does not exist": View needs to be recreated
-- If returns 0 rows but vehicles table has data: RLS blocking

-- ============================================

-- Test 6: Check RLS policies on vehicles table
SELECT 
  policyname,
  cmd,
  qual as using_clause,
  with_check
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY cmd;

-- ============================================

-- Test 7: Check if the specific vehicle exists
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_active
FROM vehicles
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- This is the vehicle ID from your logs

-- ============================================

-- Test 8: Check if that vehicle is in the view
SELECT 
  id,
  vehicle_name,
  profile_name,
  profile_id
FROM vehicles_public
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- If not found: RLS blocking this specific vehicle

-- ============================================

DO $$
DECLARE
  view_exists boolean;
  vehicles_count integer;
  view_count integer;
BEGIN
  -- Check if view exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'vehicles_public'
  ) INTO view_exists;
  
  IF NOT view_exists THEN
    RAISE NOTICE '❌ vehicles_public view does NOT exist!';
    RAISE NOTICE '👉 Run CREATE_VEHICLES_PUBLIC_VIEW_FINAL.sql to create it';
    RETURN;
  END IF;
  
  RAISE NOTICE '✅ vehicles_public view exists';
  
  -- Check vehicles table
  SELECT COUNT(*) INTO vehicles_count FROM vehicles;
  RAISE NOTICE '📊 vehicles table has % rows', vehicles_count;
  
  IF vehicles_count = 0 THEN
    RAISE NOTICE '⚠️ No vehicles in database!';
    RAISE NOTICE '👉 Add some vehicles first';
    RETURN;
  END IF;
  
  -- Check view
  SELECT COUNT(*) INTO view_count FROM vehicles_public;
  RAISE NOTICE '📊 vehicles_public view has % rows', view_count;
  
  IF view_count = 0 THEN
    RAISE NOTICE '❌ View exists but returns 0 rows!';
    RAISE NOTICE '👉 RLS is blocking access';
    RAISE NOTICE '👉 Run the RLS policy fix:';
    RAISE NOTICE '   DROP POLICY IF EXISTS "vehicles_select" ON vehicles;';
    RAISE NOTICE '   CREATE POLICY "vehicles_select_public" ON vehicles';
    RAISE NOTICE '     FOR SELECT TO anon, authenticated';
    RAISE NOTICE '     USING (profile_id = (auth.jwt() ->> ''sub''::text) OR is_active = true);';
  ELSE
    RAISE NOTICE '✅ View returns data!';
    RAISE NOTICE '👉 Flutter should be able to load vehicles';
    RAISE NOTICE '👉 Check Flutter logs for errors';
  END IF;
END $$;
