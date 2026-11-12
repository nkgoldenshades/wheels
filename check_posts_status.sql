-- Check all posts in the database with their status
SELECT 
  id,
  profile_id,
  vehicle_id,
  service_type,
  from_location,
  to_location,
  base_location,
  start_time,
  end_time,
  price,
  budget,
  capacity,
  is_active,
  created_at,
  CASE 
    WHEN vehicle_id IS NULL THEN 'Customer Post (Needed Vehicle)'
    ELSE 'Provider Post (Offering Vehicle)'
  END as post_type,
  CASE 
    WHEN end_time < NOW() THEN 'EXPIRED'
    WHEN end_time >= NOW() THEN 'ACTIVE'
  END as status
FROM posts
ORDER BY created_at DESC;

-- Check specifically for customer posts (vehicle_id IS NULL)
SELECT 
  id,
  profile_id,
  service_type,
  from_location,
  to_location,
  budget,
  persons,
  start_time,
  end_time,
  escrow_payment_id,
  status,
  is_online,
  CASE 
    WHEN end_time < NOW() THEN 'EXPIRED'
    WHEN end_time >= NOW() THEN 'ACTIVE'
  END as time_status
FROM posts
WHERE vehicle_id IS NULL
ORDER BY created_at DESC;
