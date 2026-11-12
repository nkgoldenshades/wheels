-- ============================================
-- TEST: Verify profile_name column in vehicles_public
-- ============================================

-- Check 1: Verify columns exist
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name IN ('profile_name', 'profile_avatar', 'profile_id', 'vehicle_name')
ORDER BY column_name;

-- Expected output:
-- | column_name    | data_type |
-- |----------------|-----------|
-- | profile_avatar | text      |
-- | profile_id     | text      |
-- | profile_name   | text      |  ✅
-- | vehicle_name   | text      |

-- ============================================

-- Check 2: Test view returns data with profile_name
SELECT 
  id,
  vehicle_name,
  profile_name,   -- ✅ Should show actual names (e.g., "John Doe")
  profile_avatar,
  profile_id,
  vehicle_type
FROM vehicles_public 
LIMIT 5;

-- Expected: profile_name should have values like "John Doe", "Jane Smith"
-- If NULL: Check if profiles table has full_name populated

-- ============================================

-- Check 3: Compare with profiles table
SELECT 
  v.id as vehicle_id,
  v.vehicle_name,
  v.profile_id,
  p.full_name as expected_profile_name,
  vp.profile_name as actual_profile_name,
  CASE 
    WHEN p.full_name = vp.profile_name THEN '✅ Match'
    WHEN p.full_name IS NULL THEN '⚠️ Profile missing name'
    WHEN vp.profile_name IS NULL THEN '❌ View not returning name'
    ELSE '❌ Mismatch'
  END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LEFT JOIN vehicles_public vp ON v.id = vp.id
LIMIT 5;

-- This shows if the view is correctly joining with profiles

-- ============================================

-- Check 4: Count vehicles with and without names
SELECT 
  COUNT(*) as total_vehicles,
  COUNT(profile_name) as vehicles_with_names,
  COUNT(*) - COUNT(profile_name) as vehicles_without_names
FROM vehicles_public;

-- Expected: vehicles_with_names should be > 0

-- ============================================

DO $$
DECLARE
  has_column boolean;
  sample_name text;
BEGIN
  -- Check if profile_name column exists
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'vehicles_public' 
      AND column_name = 'profile_name'
  ) INTO has_column;
  
  IF has_column THEN
    RAISE NOTICE '✅ profile_name column exists in vehicles_public';
    
    -- Get a sample value
    SELECT profile_name INTO sample_name
    FROM vehicles_public 
    WHERE profile_name IS NOT NULL
    LIMIT 1;
    
    IF sample_name IS NOT NULL THEN
      RAISE NOTICE '✅ profile_name has data: "%"', sample_name;
      RAISE NOTICE '';
      RAISE NOTICE '🎯 View is working correctly!';
      RAISE NOTICE '🔄 NEXT: Restart Flutter app completely';
      RAISE NOTICE '   flutter clean && flutter pub get && flutter run';
    ELSE
      RAISE NOTICE '⚠️ profile_name column exists but all values are NULL';
      RAISE NOTICE '👉 Check if profiles table has full_name populated';
      RAISE NOTICE '   SELECT id, full_name FROM profiles LIMIT 5;';
    END IF;
  ELSE
    RAISE NOTICE '❌ profile_name column does NOT exist in vehicles_public';
    RAISE NOTICE '👉 Recreate the view with profile_name column';
  END IF;
END $$;
