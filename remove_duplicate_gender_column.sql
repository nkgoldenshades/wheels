-- =====================================================
-- REMOVE DUPLICATE/INCORRECT GENDER COLUMN FROM VEHICLES
-- =====================================================
-- Issue: vehicles table has TWO gender-related columns:
--   1. gender (WRONG - should not be in vehicles table)
--   2. operator_gender (CORRECT - the one we want)
-- 
-- Fix: Remove the incorrect 'gender' column, keep 'operator_gender'
-- =====================================================

-- Step 1: Check what columns exist before removal
SELECT column_name 
FROM information_schema.columns
WHERE table_name = 'vehicles' 
  AND column_name IN ('gender', 'operator_gender')
ORDER BY column_name;

-- Expected result BEFORE fix:
-- gender          ← REMOVE THIS (wrong column)
-- operator_gender ← KEEP THIS (correct column)

-- =====================================================
-- Step 2: Remove the incorrect 'gender' column
-- =====================================================

ALTER TABLE public.vehicles 
  DROP COLUMN IF EXISTS gender;

-- =====================================================
-- Step 3: Verify the fix
-- =====================================================

SELECT column_name 
FROM information_schema.columns
WHERE table_name = 'vehicles' 
  AND column_name LIKE '%gender%'
ORDER BY column_name;

-- Expected result AFTER fix:
-- operator_gender ← Only this should remain

-- =====================================================
-- EXPLANATION:
-- =====================================================
-- ✅ KEEP operator_gender: Gender of the person who OPERATES the vehicle
-- ❌ REMOVE gender: This was mistakenly added to vehicles table
--    (gender should only be in 'profiles' table for user gender)
--
-- The vehicles table should have:
-- - operator_name
-- - operator_phone
-- - operator_gender  ← Driver/operator gender (for safety)
-- - operator_photo
-- - operator_license
--
-- NOT a generic 'gender' column
-- =====================================================

-- =====================================================
-- ROLLBACK (if needed):
-- =====================================================
-- If you accidentally remove the wrong column, run:
-- ALTER TABLE public.vehicles ADD COLUMN operator_gender text 
--   CHECK (operator_gender IN ('male', 'female'));
-- =====================================================
