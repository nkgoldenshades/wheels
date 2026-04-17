-- ============================================
-- TEST: Allow ALL vehicles (temporarily)
-- ============================================

-- Temporarily allow reading ALL vehicles to test if RLS is the issue
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_online" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_active" ON vehicles;

CREATE POLICY "vehicles_select_all_temp" ON vehicles
  FOR SELECT TO anon, authenticated
  USING (true);  -- Allow ALL vehicles temporarily

-- Verify
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_online,
  is_active
FROM vehicles
LIMIT 5;

-- Check the specific vehicle
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_online,
  is_active
FROM vehicles
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

DO $$
BEGIN
  RAISE NOTICE '⚠️ TEMPORARY: RLS allows ALL vehicles';
  RAISE NOTICE '🔄 Restart Flutter and check if vehicles load';
  RAISE NOTICE '📊 If vehicles load now, the issue was the RLS filter (is_online/is_active)';
  RAISE NOTICE '🔒 After testing, change back to proper RLS policy';
END $$;
