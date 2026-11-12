-- ============================================
-- CHECK: Vehicle Online Status
-- ============================================
-- Posts are filtered by online toggle, not verification

-- 1. Check if vehicles table has is_online column
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
  AND table_schema = 'public'
  AND column_name LIKE '%online%';

-- 2. Check current online status of your vehicles
SELECT 
  id,
  registration_number,
  is_active,
  is_verified,
  -- Check if is_online column exists
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'vehicles' 
        AND column_name = 'is_online'
    ) THEN 'Column exists'
    ELSE 'Column does NOT exist'
  END as online_column_status
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 3. If is_online column exists, check its values
-- SELECT 
--   id,
--   registration_number,
--   is_online,
--   is_active,
--   is_verified
-- FROM vehicles 
-- WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 4. If is_online column exists and is false, set it to true
-- UPDATE vehicles 
-- SET is_online = true 
-- WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
