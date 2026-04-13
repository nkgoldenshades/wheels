-- ============================================
-- QUICK CHECK: Why Posts Not Showing
-- ============================================
-- Replace 'YOUR_USER_ID' with your actual user ID from logs

-- 1. Check Profile Status
SELECT 
  id, 
  full_name, 
  is_active as profile_active,
  is_deleted as profile_deleted
FROM profiles 
WHERE id = 'YOUR_USER_ID';
-- Expected: is_active = true, is_deleted = false

-- 2. Check Vehicles
SELECT 
  id, 
  profile_id, 
  registration_number, 
  vehicle_type,
  is_verified
FROM vehicles 
WHERE profile_id = 'YOUR_USER_ID';
-- Expected: At least 1 vehicle exists

-- 3. Check Posts
SELECT 
  id, 
  profile_id, 
  vehicle_id, 
  service_type, 
  slot_type,
  is_active as post_active,
  created_at
FROM posts 
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC;
-- Expected: At least 1 post with is_active = true

-- 4. Check Complete Picture (Posts + Vehicles + Profile)
SELECT 
  p.id as post_id,
  p.service_type,
  p.is_active as post_active,
  v.registration_number,
  v.vehicle_type,
  prof.full_name,
  prof.is_active as profile_active,
  prof.is_deleted as profile_deleted
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
JOIN profiles prof ON p.profile_id = prof.id
WHERE p.profile_id = 'YOUR_USER_ID'
ORDER BY p.created_at DESC;
-- This shows everything together

-- ============================================
-- FIXES (if needed)
-- ============================================

-- Fix 1: Activate Profile
-- UPDATE profiles SET is_active = true WHERE id = 'YOUR_USER_ID';

-- Fix 2: Activate Posts
-- UPDATE posts SET is_active = true WHERE profile_id = 'YOUR_USER_ID';

-- Fix 3: Check if vehicle exists
-- If no vehicles found, you need to add a vehicle first

-- Fix 4: Check if post has valid vehicle_id
-- SELECT p.id, p.vehicle_id, v.id as vehicle_exists
-- FROM posts p
-- LEFT JOIN vehicles v ON p.vehicle_id = v.id
-- WHERE p.profile_id = 'YOUR_USER_ID';
-- If vehicle_exists is NULL, the vehicle was deleted
