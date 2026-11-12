-- ============================================
-- FIX: Set Vehicles to Active
-- ============================================
-- Your vehicles have is_active = false
-- This prevents them from showing in the feed

-- 1. Check current status
SELECT 
  id, 
  registration_number, 
  is_active,
  is_verified
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 2. Activate all your vehicles
UPDATE vehicles 
SET is_active = true 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 3. Verify the fix
SELECT 
  id, 
  registration_number, 
  is_active,
  is_verified
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Expected: All vehicles should now have is_active = true
