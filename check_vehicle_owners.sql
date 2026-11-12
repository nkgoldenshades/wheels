-- Check which user owns the customer vehicles
SELECT 
  vehicle_name,
  vehicle_owner,
  LEFT(profile_id, 10) as profile_prefix,
  profile_id
FROM vehicles
WHERE vehicle_owner = 'customer'
ORDER BY created_at DESC;

-- Check if the newly created vehicle exists
SELECT 
  id,
  vehicle_name,
  vehicle_owner,
  profile_id,
  created_at
FROM vehicles
WHERE id = '2d43ba15-9411-4028-a9d5-272280e25a9c';

-- If you want to UPDATE the customer vehicles to belong to your current user:
-- UPDATE vehicles 
-- SET profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1'
-- WHERE vehicle_owner = 'customer'
--   AND profile_id != 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
