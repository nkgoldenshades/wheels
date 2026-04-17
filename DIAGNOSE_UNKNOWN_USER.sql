-- ============================================
-- DIAGNOSE: Why "Unknown User" is showing
-- ============================================

-- Test 1: Check if vehicles_public view exists and has data
DO $$
DECLARE
  view_count integer;
  sample_name text;
BEGIN
  -- Check if view exists
  SELECT COUNT(*) INTO view_count
  FROM information_schema.tables
  WHERE table_name = 'vehicles_public';
  
  IF view_count = 0 THEN
    RAISE NOTICE '❌ vehicles_public view does NOT exist';
    RAISE NOTICE '👉 Create the view first';
  ELSE
    RAISE NOTICE '✅ vehicles_public view exists';
    
    -- Check if it has data
    EXECUTE 'SELECT COUNT(*) FROM vehicles_public' INTO view_count;
    RAISE NOTICE '📊 View has % rows', view_count;
    
    IF view_count = 0 THEN
      RAISE NOTICE '⚠️ View exists but has no data';
      RAISE NOTICE '👉 Check RLS policies or vehicles table';
    ELSE
      -- Check if profile_name column exists and has data
      BEGIN
        EXECUTE 'SELECT profile_name FROM vehicles_public LIMIT 1' INTO sample_name;
        IF sample_name IS NULL THEN
          RAISE NOTICE '⚠️ profile_name column exists but is NULL';
          RAISE NOTICE '👉 Check if profiles table has full_name populated';
        ELSE
          RAISE NOTICE '✅ profile_name has data: "%"', sample_name;
        END IF;
      EXCEPTION
        WHEN undefined_column THEN
          RAISE NOTICE '❌ profile_name column does NOT exist in view';
          RAISE NOTICE '👉 Recreate view with profile_name column';
      END;
    END IF;
  END IF;
END $$;

-- ============================================

-- Test 2: Show sample data from view
SELECT 
  id,
  vehicle_name,
  profile_name,  -- This should show actual names
  profile_id,
  vehicle_type
FROM vehicles_public 
LIMIT 5;

-- ============================================

-- Test 3: Check if profiles have names
SELECT 
  'Profiles with vehicles' as check_type,
  COUNT(*) as total,
  COUNT(p.full_name) as with_names,
  COUNT(*) - COUNT(p.full_name) as without_names
FROM profiles p
WHERE EXISTS (
  SELECT 1 FROM vehicles v WHERE v.profile_id = p.id
);

-- ============================================

-- Test 4: Compare vehicles table with view
SELECT 
  v.id,
  v.vehicle_name,
  v.profile_id,
  p.full_name as profile_full_name,
  vp.profile_name as view_profile_name,
  CASE 
    WHEN vp.id IS NULL THEN '❌ Not in view'
    WHEN vp.profile_name IS NULL THEN '⚠️ Name is NULL'
    WHEN vp.profile_name = p.full_name THEN '✅ Correct'
    ELSE '⚠️ Mismatch'
  END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LEFT JOIN vehicles_public vp ON v.id = vp.id
LIMIT 10;

-- ============================================

-- Test 5: Check posts and their vehicles
SELECT 
  p.id as post_id,
  p.vehicle_id,
  v.vehicle_name,
  v.profile_id as vehicle_owner,
  prof.full_name as owner_name,
  vp.profile_name as view_name,
  CASE 
    WHEN v.id IS NULL THEN '❌ Vehicle not found'
    WHEN vp.id IS NULL THEN '❌ Vehicle not in view (RLS?)'
    WHEN vp.profile_name IS NULL THEN '⚠️ Name is NULL'
    ELSE '✅ OK'
  END as status
FROM posts p
LEFT JOIN vehicles v ON p.vehicle_id = v.id
LEFT JOIN profiles prof ON v.profile_id = prof.id
LEFT JOIN vehicles_public vp ON v.id = vp.id
WHERE p.is_active = true
LIMIT 10;

-- ============================================

-- Test 6: Check RLS policies on vehicles
SELECT 
  policyname,
  cmd,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY cmd;

-- ============================================

-- Test 7: Check view definition
SELECT pg_get_viewdef('vehicles_public', true);

-- ============================================

-- INTERPRETATION GUIDE:

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎯 INTERPRETATION GUIDE:';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 1: View exists and has data?';
  RAISE NOTICE '  ✅ If "profile_name has data" → View is working';
  RAISE NOTICE '  ❌ If "profile_name is NULL" → Profiles missing names';
  RAISE NOTICE '  ❌ If "profile_name does NOT exist" → Recreate view';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 2: Shows actual data?';
  RAISE NOTICE '  ✅ If profile_name shows names → View is correct';
  RAISE NOTICE '  ❌ If profile_name is NULL → Check Test 3';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 3: Profiles have names?';
  RAISE NOTICE '  ✅ If with_names > 0 → Some profiles have names';
  RAISE NOTICE '  ❌ If with_names = 0 → No profiles have names set';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 4: View matches vehicles table?';
  RAISE NOTICE '  ✅ If all "Correct" → View is working';
  RAISE NOTICE '  ❌ If "Not in view" → RLS blocking access';
  RAISE NOTICE '  ⚠️ If "Name is NULL" → Profiles missing names';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 5: Posts can find vehicles?';
  RAISE NOTICE '  ✅ If all "OK" → Everything is working';
  RAISE NOTICE '  ❌ If "Vehicle not found" → Vehicle deleted';
  RAISE NOTICE '  ❌ If "Vehicle not in view" → RLS blocking';
  RAISE NOTICE '  ⚠️ If "Name is NULL" → Profiles missing names';
  RAISE NOTICE '';
  RAISE NOTICE 'Test 6: RLS policies';
  RAISE NOTICE '  Check if SELECT policy is too restrictive';
  RAISE NOTICE '  Should allow: profile_id = auth.uid() OR true for public view';
  RAISE NOTICE '';
END $$;

-- ============================================

-- QUICK FIX: If profiles are missing names
/*
UPDATE profiles 
SET full_name = 'User ' || SUBSTRING(id, 1, 8)
WHERE full_name IS NULL 
  AND EXISTS (SELECT 1 FROM vehicles WHERE profile_id = profiles.id);
*/

-- QUICK FIX: If view doesn't have profile_name
/*
DROP VIEW IF EXISTS vehicles_public CASCADE;

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.*,
  p.full_name AS profile_name,
  p.profile_photo_url AS profile_avatar,
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

GRANT SELECT ON vehicles_public TO anon, authenticated;
*/
