-- ============================================
-- RECREATE: vehicles_public view with user_name column
-- ============================================
-- This will add the missing user_name column to your view

-- Step 1: Drop the existing view
DROP VIEW IF EXISTS vehicles_public CASCADE;

-- Step 2: Create new view with user_name column
CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  -- All existing columns from vehicles table
  v.id,
  v.profile_id,
  v.vehicle_owner,
  v.vehicle_type,
  v.registration_number,
  v.seating_capacity,
  v.vehicle_photo_url,
  v.gallery_images,
  v.video_url,
  v.rc_front_url,
  v.rc_back_url,
  v.insurance_number,
  v.insurance_expiry,
  v.insurance_document_url,
  v.pollution_certificate_url,
  v.pollution_expiry,
  v.fitness_certificate_url,
  v.fitness_expiry,
  v.total_trips,
  v.total_reviews,
  v.active_posts_count,
  v.is_verified,
  v.verified_at,
  v.is_online,
  v.created_at,
  v.updated_at,
  v.operator_id,
  v.operator_name,
  v.operator_phone,
  v.operator_profile_photo_url,
  v.vehicle_name,
  v.is_active,
  
  -- ✅ ADD USER INFORMATION FROM PROFILES TABLE
  p.full_name AS user_name,           -- This is the key column!
  p.profile_photo_url AS user_avatar,
  p.phone_number AS user_phone,
  
  -- Ownership flag
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id  -- Join with profiles table

WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

-- Step 3: Grant access to the view
GRANT SELECT ON vehicles_public TO anon, authenticated;

-- Step 4: Verify the view has user_name column
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name IN ('user_name', 'user_avatar', 'profile_id', 'vehicle_name')
ORDER BY column_name;

-- Expected output:
-- | column_name  | data_type |
-- |--------------|-----------|
-- | profile_id   | text      |
-- | user_avatar  | text      |
-- | user_name    | text      |  ← This should appear!
-- | vehicle_name | text      |

-- Step 5: Test the view returns data with user_name
SELECT 
  id,
  vehicle_name,
  user_name,      -- ✅ Should show actual names now
  profile_id,
  vehicle_type
FROM vehicles_public 
LIMIT 5;

-- Expected: user_name column should have values like "John Doe"
-- If NULL: Check if profiles table has full_name populated

-- Step 6: Check if profiles have names
SELECT 
  p.id,
  p.full_name,
  p.email,
  COUNT(v.id) as vehicle_count
FROM profiles p
LEFT JOIN vehicles v ON v.profile_id = p.id
GROUP BY p.id, p.full_name, p.email
HAVING COUNT(v.id) > 0
LIMIT 5;

-- This shows which users have vehicles and whether they have names set

-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ vehicles_public view recreated with user_name column!';
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Check the SELECT results above:';
  RAISE NOTICE '   1. Verify user_name column exists in schema';
  RAISE NOTICE '   2. Verify user_name has values (not NULL)';
  RAISE NOTICE '   3. Verify profiles have full_name populated';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT: Restart your Flutter app completely';
  RAISE NOTICE '   flutter clean && flutter pub get && flutter run';
END $$;
