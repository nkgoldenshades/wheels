-- Check the newly created customer vehicle
SELECT 
  id,
  profile_id,
  vehicle_name,
  vehicle_type,
  vehicle_owner,
  created_at
FROM vehicles
WHERE id = '2d43ba15-9411-4028-a9d5-272280e25a9c';

-- Check all customer vehicles for user GbsFkKmcHCQFJ0ceVoBWz2punch1
SELECT 
  id,
  profile_id,
  vehicle_name,
  vehicle_type,
  vehicle_owner,
  created_at
FROM vehicles
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1'
  AND vehicle_owner = 'customer'
ORDER BY created_at DESC;

-- Check what profile_id was actually saved
SELECT 
  id,
  profile_id,
  vehicle_name,
  vehicle_owner
FROM vehicles
WHERE vehicle_owner = 'customer'
ORDER BY created_at DESC
LIMIT 5;
