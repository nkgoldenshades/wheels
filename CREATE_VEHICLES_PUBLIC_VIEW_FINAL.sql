-- ============================================
-- CREATE: vehicles_public View (Final Version)
-- ============================================
-- Based on your actual schema with vehicle_sensitive_info table

-- Drop old view if exists
DROP VIEW IF EXISTS vehicles_public CASCADE;

-- Create view that exposes only safe vehicle data + user info
CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  -- Safe vehicle columns (from vehicles table)
  v.id,
  v.profile_id,
  v.vehicle_owner,
  v.vehicle_type,
  v.registration_number,
  v.seating_capacity,
  v.vehicle_photo_url,
  v.gallery_images,
  v.video_url,
  v.total_trips,
  v.total_reviews,
  v.active_posts_count,
  v.is_verified,
  v.verified_at,
  v.is_online,
  v.created_at,
  v.updated_at,
  v.vehicle_name,
  v.is_active,
  
  -- User information (from profiles table)
  p.full_name AS profile_name,
  p.profile_photo_url AS profile_avatar,
  p.average_rating AS user_rating,
  p.total_reviews AS user_total_reviews,
  
  -- Ownership flag
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id

WHERE 
  -- Show active vehicles OR user's own vehicles
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

-- Grant access to the view
GRANT SELECT ON vehicles_public TO anon, authenticated;

-- ============================================

-- Create RLS policy for vehicles table (SELECT)
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_public" ON vehicles;

CREATE POLICY "vehicles_select_public" ON vehicles
  FOR SELECT
  TO anon, authenticated
  USING (
    -- User's own vehicles (for management)
    profile_id = (auth.jwt() ->> 'sub'::text)
    OR
    -- All active vehicles (for browsing)
    is_active = true
  );

-- ============================================

-- Verify the view works
SELECT 
  id,
  vehicle_name,
  profile_name,  -- Should show actual names
  profile_id,
  vehicle_type,
  is_active
FROM vehicles_public
LIMIT 5;

-- Check column list
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name IN ('profile_name', 'profile_avatar', 'vehicle_name', 'profile_id')
ORDER BY column_name;

-- Verify posts can find their vehicles
SELECT 
  p.id as post_id,
  p.vehicle_id,
  v.vehicle_name,
  v.profile_name,
  CASE 
    WHEN v.id IS NULL THEN '❌ Vehicle not found'
    ELSE '✅ Found'
  END as status
FROM posts p
LEFT JOIN vehicles_public v ON p.vehicle_id = v.id
WHERE p.is_active = true
LIMIT 10;

-- Expected: All posts should show "✅ Found"

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ vehicles_public view created successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 View exposes:';
  RAISE NOTICE '  ✅ Safe vehicle data (no sensitive info)';
  RAISE NOTICE '  ✅ User information (profile_name, profile_avatar)';
  RAISE NOTICE '  ✅ Ownership flag (is_owner)';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 Sensitive data protected:';
  RAISE NOTICE '  ❌ RC documents (in vehicle_sensitive_info table)';
  RAISE NOTICE '  ❌ Insurance details (in vehicle_sensitive_info table)';
  RAISE NOTICE '  ❌ Operator details (in vehicle_sensitive_info table)';
  RAISE NOTICE '';
  RAISE NOTICE '✅ RLS policy created:';
  RAISE NOTICE '  - Users can see their own vehicles';
  RAISE NOTICE '  - Everyone can see active vehicles';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT: Restart Flutter app';
  RAISE NOTICE '   flutter clean && flutter pub get && flutter run';
  RAISE NOTICE '';
  RAISE NOTICE '✅ "Unknown User" should be fixed after restart!';
END $$;
