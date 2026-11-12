-- ============================================
-- CREATE PUBLIC VEHICLES VIEW
-- ============================================
-- This creates a view with only public vehicle info
-- that all users can access (no RLS restrictions)
-- ============================================

-- Step 1: Create the view with public vehicle information
CREATE OR REPLACE VIEW public_vehicles AS
SELECT 
  id,
  profile_id,
  vehicle_type,
  vehicle_name,
  seating_capacity,
  vehicle_photo_url,
  average_rating,
  total_ratings,
  total_bookings,
  is_verified,
  created_at,
  is_online,
  -- Add any other fields you want to be public
  -- Exclude sensitive fields like registration_number, insurance details, etc.
  NULL as registration_number,  -- Hide sensitive data
  NULL as insurance_number,
  NULL as rc_front_url,
  NULL as rc_back_url
FROM vehicles
WHERE is_online = true;  -- Only show online vehicles

-- Step 2: Grant access to everyone (no RLS needed on views)
GRANT SELECT ON public_vehicles TO anon, authenticated;

-- Step 3: Verify the view
SELECT 
  'VERIFICATION' as status,
  COUNT(*) as total_vehicles
FROM public_vehicles;

-- Step 4: Test as anonymous user
SET ROLE anon;
SELECT 
  'TEST AS GUEST' as test,
  COUNT(*) as visible_vehicles
FROM public_vehicles;
RESET ROLE;

-- Step 5: Show sample data
SELECT 
  id,
  vehicle_name,
  vehicle_type,
  seating_capacity,
  average_rating
FROM public_vehicles
LIMIT 5;

-- ============================================
-- USAGE IN FLUTTER
-- ============================================
-- Change your query from:
--   .from('vehicles').select()
-- To:
--   .from('public_vehicles').select()
-- ============================================