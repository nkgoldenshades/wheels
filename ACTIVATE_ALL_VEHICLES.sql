-- ============================================
-- ACTIVATE ALL VEHICLES
-- ============================================
-- Set is_active = true for all existing vehicles
-- Set is_online = true for all existing vehicles

-- 1. Activate all vehicles
UPDATE vehicles 
SET 
  is_active = true,
  is_online = true
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 2. Verify the update
SELECT 
  id,
  registration_number,
  is_active,
  is_online,
  is_verified
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Expected: All should have is_active = true, is_online = true

-- 3. Check posts are also active
SELECT 
  p.id as post_id,
  p.is_active as post_active,
  v.registration_number,
  v.is_active as vehicle_active,
  v.is_online as vehicle_online
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Expected: All posts should have is_active = true
