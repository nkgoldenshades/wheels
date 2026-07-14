-- =====================================================
-- CHECK IF operator_gender COLUMN EXISTS
-- =====================================================

-- Query 1: Check all operator columns in vehicles table
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'vehicles' 
  AND column_name LIKE '%operator%'
ORDER BY column_name;

-- Expected result should include:
-- operator_gender    | text | YES | NULL
-- operator_license   | text | YES | NULL
-- operator_name      | text | YES | NULL
-- operator_phone     | text | YES | NULL
-- operator_photo     | text | YES | NULL

-- =====================================================
-- Query 2: Check if the CHECK constraint exists
-- =====================================================
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.vehicles'::regclass
  AND conname LIKE '%operator_gender%';

-- =====================================================
-- Query 3: Check if the index exists
-- =====================================================
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'vehicles'
  AND indexname LIKE '%operator_gender%';

-- =====================================================
-- INTERPRETATION:
-- =====================================================
-- If Query 1 shows 'operator_gender' → Column EXISTS ✅
-- If Query 1 does NOT show 'operator_gender' → Column MISSING ❌
--    → You need to run: 006_add_operator_gender.sql
-- =====================================================
