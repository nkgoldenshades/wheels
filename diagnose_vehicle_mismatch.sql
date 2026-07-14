-- Diagnostic: Check why customer posts can't find their vehicles

-- 1. Check all customer posts and their vehicle_ids
SELECT 
  p.id as post_id,
  p.profile_id,
  p.vehicle_id,
  p.post_type,
  p.service_type,
  p.created_at as post_created
FROM posts p
WHERE p.profile_id = 'GDsF9KmcHCQFJ0ceW8Wz2p...' -- Replace with your user ID
ORDER BY p.created_at DESC;

-- 2. Check all customer vehicles for the same user
SELECT 
  v.id as vehicle_id,
  v.profile_id,
  v.vehicle_name,
  v.vehicle_owner,
  v.created_at as vehicle_created
FROM vehicles v
WHERE v.profile_id = 'GDsF9KmcHCQFJ0ceW8Wz2p...' -- Replace with your user ID
  AND v.vehicle_owner = 'customer'
ORDER BY v.created_at DESC;

-- 3. Find posts with mismatched vehicle_ids (vehicle doesn't exist)
SELECT 
  p.id as post_id,
  p.vehicle_id as post_vehicle_id,
  p.service_type,
  p.created_at,
  v.id as actual_vehicle_id,
  v.vehicle_name
FROM posts p
LEFT JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.profile_id = 'GDsF9KmcHCQFJ0ceW8Wz2p...' -- Replace with your user ID
  AND v.id IS NULL -- vehicle not found
ORDER BY p.created_at DESC;

-- 4. Check if vehicles exist but with wrong vehicle_owner
SELECT 
  p.id as post_id,
  p.vehicle_id,
  v.vehicle_name,
  v.vehicle_owner,
  CASE 
    WHEN v.vehicle_owner = 'customer' THEN '✅ Correct'
    WHEN v.vehicle_owner = 'provider' THEN '❌ Wrong (should be customer)'
    ELSE '❓ Unknown'
  END as status
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.profile_id = 'GDsF9KmcHCQFJ0ceW8Wz2p...' -- Replace with your user ID
ORDER BY p.created_at DESC;

-- 5. Count posts by type and vehicle match status
SELECT 
  p.post_type,
  COUNT(*) as total_posts,
  COUNT(v.id) as vehicles_found,
  COUNT(*) - COUNT(v.id) as vehicles_missing
FROM posts p
LEFT JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.profile_id = 'GDsF9KmcHCQFJ0ceW8Wz2p...' -- Replace with your user ID
GROUP BY p.post_type;
