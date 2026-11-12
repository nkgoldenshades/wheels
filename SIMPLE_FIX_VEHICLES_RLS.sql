-- ============================================
-- SIMPLE FIX: Allow Reading Online Vehicles
-- ============================================
-- No view needed - just query vehicles table with is_online = true

-- Step 1: Update RLS policy on vehicles table
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_public" ON vehicles;

CREATE POLICY "vehicles_select_online" ON vehicles
  FOR SELECT
  TO anon, authenticated
  USING (
    -- User's own vehicles (for management)
    profile_id = (auth.jwt() ->> 'sub'::text)
    OR
    -- All online vehicles (for browsing)
    is_online = true
  );

-- ============================================

-- Step 2: Verify it works
-- Test 1: Can we see online vehicles?
SELECT COUNT(*) as online_vehicles
FROM vehicles
WHERE is_online = true;

-- Expected: > 0

-- Test 2: Can we see the specific vehicle?
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_online
FROM vehicles
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- Expected: 1 row with is_online = true

-- Test 3: Can we join with profiles?
SELECT 
  v.id,
  v.vehicle_name,
  v.is_online,
  p.full_name as profile_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
LIMIT 5;

-- Expected: Rows with profile_name populated

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ RLS policy updated for vehicles table';
  RAISE NOTICE '';
  RAISE NOTICE '📋 New policy allows:';
  RAISE NOTICE '  1. Users can see their own vehicles';
  RAISE NOTICE '  2. Everyone can see online vehicles (is_online = true)';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT: Restart Flutter app';
  RAISE NOTICE '   flutter clean && flutter pub get && flutter run';
  RAISE NOTICE '';
  RAISE NOTICE '✅ After restart, vehicles should load!';
END $$;
