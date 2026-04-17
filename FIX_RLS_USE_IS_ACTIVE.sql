-- ============================================
-- FIX: Use is_active instead of is_online
-- ============================================

-- Update RLS policy to use is_active
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_online" ON vehicles;

CREATE POLICY "vehicles_select_active" ON vehicles
  FOR SELECT TO anon, authenticated
  USING (
    profile_id = (auth.jwt() ->> 'sub'::text)
    OR
    is_active = true
  );

-- Verify it works
SELECT 
  id,
  vehicle_name,
  profile_id,
  is_active,
  is_online
FROM vehicles
WHERE id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- Check if we can query with is_active = true
SELECT COUNT(*) as active_vehicles
FROM vehicles
WHERE is_active = true;

-- Test the join
SELECT 
  v.id,
  v.vehicle_name,
  v.is_active,
  p.full_name as profile_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_active = true
LIMIT 5;

DO $$
BEGIN
  RAISE NOTICE '✅ RLS policy updated to use is_active';
  RAISE NOTICE '🔄 Restart Flutter app now';
END $$;
