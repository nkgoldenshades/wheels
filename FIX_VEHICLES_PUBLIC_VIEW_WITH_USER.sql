-- ============================================
-- FIX: Add User Information to vehicles_public View
-- ============================================

-- Drop the old view
DROP VIEW IF EXISTS vehicles_public;

-- Create updated view with user information (matching your exact schema)
CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.id,
  v.profile_id,
  v.vehicle_type,
  v.vehicle_name,
  v.seating_capacity,
  v.vehicle_photo_url,
  v.gallery_images,
  v.video_url,
  v.created_at,
  v.updated_at,
  v.is_online,
  v.vehicle_owner,
  v.total_trips,
  v.total_reviews,
  v.active_posts_count,
  v.is_verified,
  v.verified_at,
  v.operator_name,
  v.operator_phone,
  v.operator_profile_photo_url,
  v.registration_number,  -- Added from your schema
  v.is_active,            -- Added from your schema
  
  -- ✅ ADD USER INFORMATION
  p.full_name as user_name,  -- This fixes "Unknown User"
  p.profile_photo_url as user_avatar,
  
  -- Ownership flag
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id  -- ✅ Join with profiles table

WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

-- Note: RLS policies on views are not supported by Supabase
-- The view inherits security from the underlying vehicles table

-- Verify
SELECT 
  id,
  vehicle_name,
  user_name,  -- ✅ Should show actual user names now
  profile_id
FROM vehicles_public 
LIMIT 5;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ vehicles_public view updated with user information!';
  RAISE NOTICE '✅ user_name column now available (from profiles.full_name)';
  RAISE NOTICE '✅ Should fix "Unknown User" issue';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT: Restart your Flutter app to see changes';
END $$;
