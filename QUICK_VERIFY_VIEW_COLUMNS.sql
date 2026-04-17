-- ============================================
-- QUICK VERIFY: What columns does your view actually have?
-- ============================================

-- Test 1: Try to select profile_name
DO $$
BEGIN
  PERFORM profile_name FROM vehicles_public LIMIT 1;
  RAISE NOTICE '✅ View has profile_name column';
EXCEPTION
  WHEN undefined_column THEN
    RAISE NOTICE '❌ View does NOT have profile_name column';
    RAISE NOTICE '👉 View might have user_name instead';
END $$;

-- Test 2: Try to select user_name
DO $$
BEGIN
  PERFORM user_name FROM vehicles_public LIMIT 1;
  RAISE NOTICE '✅ View has user_name column';
EXCEPTION
  WHEN undefined_column THEN
    RAISE NOTICE '❌ View does NOT have user_name column';
END $$;

-- ============================================

-- Show all name-related columns
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND (
    column_name LIKE '%name%' OR 
    column_name LIKE '%avatar%'
  )
ORDER BY column_name;

-- ============================================

-- Try to query the view with both column names
-- This will show which one actually exists

-- Try profile_name:
DO $$
DECLARE
  test_name text;
BEGIN
  BEGIN
    SELECT profile_name INTO test_name FROM vehicles_public LIMIT 1;
    RAISE NOTICE '✅ profile_name exists, sample value: %', COALESCE(test_name, 'NULL');
  EXCEPTION
    WHEN undefined_column THEN
      RAISE NOTICE '❌ profile_name column does not exist';
  END;
END $$;

-- Try user_name:
DO $$
DECLARE
  test_name text;
BEGIN
  BEGIN
    SELECT user_name INTO test_name FROM vehicles_public LIMIT 1;
    RAISE NOTICE '✅ user_name exists, sample value: %', COALESCE(test_name, 'NULL');
  EXCEPTION
    WHEN undefined_column THEN
      RAISE NOTICE '❌ user_name column does not exist';
  END;
END $$;

-- ============================================

-- Show view definition
RAISE NOTICE '📋 View definition:';
SELECT pg_get_viewdef('vehicles_public', true);

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎯 INTERPRETATION:';
  RAISE NOTICE '';
  RAISE NOTICE 'If you see "✅ profile_name exists":';
  RAISE NOTICE '  → Flutter is already configured correctly';
  RAISE NOTICE '  → Just restart Flutter app';
  RAISE NOTICE '';
  RAISE NOTICE 'If you see "✅ user_name exists" (not profile_name):';
  RAISE NOTICE '  → View has user_name, not profile_name';
  RAISE NOTICE '  → Either update view to use profile_name';
  RAISE NOTICE '  → OR update Flutter to read user_name first';
  RAISE NOTICE '';
  RAISE NOTICE 'If both are NULL:';
  RAISE NOTICE '  → Check profiles table: SELECT id, full_name FROM profiles LIMIT 5;';
END $$;
