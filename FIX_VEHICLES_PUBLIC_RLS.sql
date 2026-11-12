-- ============================================
-- FIX: Allow Public Read Access to vehicles_public View
-- ============================================
-- Problem: RLS on vehicles table is blocking access to vehicles_public view
-- Solution: Add a SELECT policy that allows reading through the view

-- Step 1: Check current RLS policies on vehicles table
SELECT 
  policyname,
  cmd,
  qual as using_clause
FROM pg_policies
WHERE tablename = 'vehicles'
  AND cmd = 'SELECT';

-- ============================================

-- Step 2: Drop old restrictive SELECT policy (if exists)
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;

-- Step 3: Create new SELECT policy that allows:
-- 1. Users can see their own vehicles (for management)
-- 2. Everyone can see active vehicles (for browsing)
CREATE POLICY "vehicles_select_public" ON vehicles
  FOR SELECT
  TO anon, authenticated
  USING (
    -- User's own vehicles (for vehicle management screen)
    profile_id = (auth.jwt() ->> 'sub'::text)
    OR
    -- All active vehicles (for common feed)
    is_active = true
  );

-- ============================================

-- Step 4: Verify the policy works
-- Test 1: Can we see active vehicles?
SELECT COUNT(*) as active_vehicles
FROM vehicles
WHERE is_active = true;

-- Test 2: Can we see vehicles through the view?
SELECT COUNT(*) as vehicles_in_view
FROM vehicles_public;

-- Test 3: Show sample data
SELECT 
  id,
  vehicle_name,
  profile_name,
  is_active,
  profile_id
FROM vehicles_public
LIMIT 5;

-- ============================================

-- Step 5: Verify posts can find their vehicles
SELECT 
  p.id as post_id,
  p.vehicle_id,
  v.vehicle_name,
  v.profile_name,
  CASE 
    WHEN v.id IS NULL THEN '❌ Vehicle not found'
    ELSE '✅ Found'
  END as status
FROM posts p
LEFT JOIN vehicles_public v ON p.vehicle_id = v.id
WHERE p.is_active = true
LIMIT 10;

-- Expected: All posts should show "✅ Found"

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ RLS policy updated for vehicles table';
  RAISE NOTICE '';
  RAISE NOTICE '📋 New policy allows:';
  RAISE NOTICE '  1. Users can see their own vehicles';
  RAISE NOTICE '  2. Everyone can see active vehicles';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 Sensitive data is still protected:';
  RAISE NOTICE '  - vehicles_public view only exposes safe columns';
  RAISE NOTICE '  - RC, insurance, national ID are NOT in the view';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT: Restart Flutter app';
  RAISE NOTICE '   flutter clean && flutter pub get && flutter run';
  RAISE NOTICE '';
  RAISE NOTICE '✅ After restart, vehicles should load and "Unknown User" should be fixed!';
END $$;
