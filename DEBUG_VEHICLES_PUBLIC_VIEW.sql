-- ============================================
-- DEBUG: Check vehicles_public View
-- ============================================

-- Check if view exists
SELECT EXISTS (
  SELECT 1 
  FROM information_schema.views 
  WHERE table_schema = 'public' 
  AND table_name = 'vehicles_public'
) as view_exists;

-- Check view definition
SELECT definition 
FROM pg_views 
WHERE schemaname = 'public' 
AND viewname = 'vehicles_public';

-- Check what columns the view has
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vehicles_public'
ORDER BY ordinal_position;

-- Check actual data from view
SELECT 
  id,
  vehicle_name,
  user_name,  -- This should show actual names
  profile_id
FROM vehicles_public
LIMIT 5;

-- Check if profiles have full_name data
SELECT 
  id,
  full_name,
  email
FROM profiles
LIMIT 5;

-- Check vehicles with their profile data
SELECT 
  v.id,
  v.vehicle_name,
  v.profile_id,
  p.full_name as owner_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LIMIT 5;
