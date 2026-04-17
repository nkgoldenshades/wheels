-- ============================================
-- VERIFY: vehicles_public View is Working
-- ============================================
-- Run these queries in Supabase SQL Editor to verify the view

-- ✅ CHECK 1: Does the view exist?
SELECT 
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_name = 'vehicles_public';

-- Expected: 1 row with table_type = 'VIEW'
-- If empty: View doesn't exist, run FIX_VEHICLES_PUBLIC_VIEW_WITH_USER.sql

-- ============================================

-- ✅ CHECK 2: Does the view return data with user_name?
SELECT 
  id,
  vehicle_name,
  user_name,  -- ⚠️ This should NOT be NULL
  profile_id,
  vehicle_type
FROM vehicles_public 
LIMIT 5;

-- Expected: Rows with user_name showing actual names (e.g., "John Doe")
-- If user_name is NULL: View join is broken, recreate view
-- If no rows: No vehicles in database

-- ============================================

-- ✅ CHECK 3: Compare vehicles table with view
SELECT 
  'vehicles table' as source,
  v.id,
  v.vehicle_name,
  v.profile_id,
  p.full_name as expected_user_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LIMIT 3

UNION ALL

SELECT 
  'vehicles_public view' as source,
  id,
  vehicle_name,
  profile_id,
  user_name as expected_user_name
FROM vehicles_public
LIMIT 3;

-- Expected: Both sources should show same data
-- If view shows NULL but table shows names: View definition is wrong

-- ============================================

-- ✅ CHECK 4: Verify profiles have full_name
SELECT 
  id,
  full_name,
  email
FROM profiles 
WHERE id IN (
  SELECT DISTINCT profile_id FROM vehicles LIMIT 5
);

-- Expected: Rows with full_name populated
-- If full_name is NULL: Users need to set their names in profiles

-- ============================================

-- ✅ CHECK 5: View definition
SELECT pg_get_viewdef('vehicles_public', true);

-- Expected: Should show CREATE VIEW with LEFT JOIN profiles
-- Look for: "p.full_name AS user_name"

-- ============================================

-- 🎯 INTERPRETATION GUIDE:

-- ✅ ALL CHECKS PASS:
--    - View exists
--    - Returns data with user_name
--    - Matches vehicles table
--    - Profiles have names
--    → Flutter should work after full restart

-- ❌ CHECK 2 FAILS (user_name is NULL):
--    → Run: FIX_VEHICLES_PUBLIC_VIEW_WITH_USER.sql

-- ❌ CHECK 4 FAILS (profiles.full_name is NULL):
--    → Users need to update their profiles with names
--    → Or use operator_name as fallback

-- ❌ CHECK 1 FAILS (view doesn't exist):
--    → Run: FIX_VEHICLES_PUBLIC_VIEW_WITH_USER.sql

-- ============================================

-- 🔧 QUICK FIX: Recreate view if needed
/*
DROP VIEW IF EXISTS vehicles_public;

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.*,
  p.full_name as user_name,
  p.profile_photo_url as user_avatar,
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);
*/

-- ============================================

-- 📊 SAMPLE OUTPUT (what you should see):

-- CHECK 2 Result:
-- | id   | vehicle_name | user_name  | profile_id | vehicle_type |
-- |------|-------------|-----------|-----------|-------------|
-- | v123 | Honda City  | John Doe  | u456      | car         |
-- | v124 | Yamaha R15  | Jane Smith| u457      | bike        |

-- If you see this ✅ → View is working correctly
-- If user_name is NULL ❌ → View needs to be fixed

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ Run all checks above';
  RAISE NOTICE '✅ Verify user_name column has values (not NULL)';
  RAISE NOTICE '✅ If any check fails, see INTERPRETATION GUIDE';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 After fixing, restart Flutter app completely';
END $$;
