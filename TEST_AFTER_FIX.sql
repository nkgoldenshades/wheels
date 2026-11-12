-- ============================================
-- TEST: Verify "Unknown User" Fix is Working
-- ============================================
-- Run this AFTER rebuilding the Flutter app

-- ============================================
-- TEST 1: Check vehicles table has data
-- ============================================
SELECT 
    COUNT(*) as total_vehicles,
    COUNT(CASE WHEN is_online = true THEN 1 END) as online_vehicles,
    COUNT(CASE WHEN profile_id IS NOT NULL THEN 1 END) as vehicles_with_owner
FROM vehicles;

-- ✅ Expected: All counts > 0
-- ❌ If total_vehicles = 0: No vehicles exist
-- ❌ If vehicles_with_owner = 0: Vehicles have no owner

-- ============================================
-- TEST 2: Check profiles have names
-- ============================================
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN full_name IS NOT NULL AND full_name != '' THEN 1 END) as profiles_with_names,
    COUNT(*) - COUNT(CASE WHEN full_name IS NOT NULL AND full_name != '' THEN 1 END) as profiles_without_names
FROM profiles;

-- ✅ Expected: profiles_with_names > 0, profiles_without_names = 0
-- ❌ If profiles_without_names > 0: Some profiles don't have names

-- ============================================
-- TEST 3: Verify the join works
-- ============================================
SELECT 
    v.id as vehicle_id,
    v.vehicle_name,
    v.vehicle_type,
    v.profile_id,
    p.full_name as owner_name,
    p.email as owner_email,
    v.is_online,
    v.created_at
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
ORDER BY v.created_at DESC
LIMIT 10;

-- ✅ Expected: owner_name column shows actual names (not NULL)
-- ❌ If owner_name is NULL: Either profile doesn't exist or full_name is NULL

-- ============================================
-- TEST 4: Check specific vehicle from logs
-- ============================================
-- Replace 'e067af6a-4d22-47a1-9a7e-f02a3badd787' with the vehicle ID from your logs

SELECT 
    v.id,
    v.vehicle_name,
    v.vehicle_type,
    v.profile_id,
    p.full_name as owner_name,
    p.email,
    v.is_online,
    CASE 
        WHEN p.id IS NULL THEN '❌ Profile does not exist'
        WHEN p.full_name IS NULL OR p.full_name = '' THEN '❌ Profile exists but no name'
        ELSE '✅ Profile has name'
    END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.id = 'e067af6a-4d22-47a1-9a7e-f02a3badd787';

-- ✅ Expected: status = '✅ Profile has name'
-- ❌ If '❌ Profile does not exist': Create profile first
-- ❌ If '❌ Profile exists but no name': Update profile.full_name

-- ============================================
-- TEST 5: Simulate what Flutter sees
-- ============================================
-- This simulates the exact query Flutter makes

SELECT 
    json_agg(
        json_build_object(
            'id', v.id,
            'vehicle_name', v.vehicle_name,
            'vehicle_type', v.vehicle_type,
            'profile_id', v.profile_id,
            'is_online', v.is_online,
            'profile_name', p.full_name,
            'profile_avatar', p.profile_photo_url
        )
    ) as flutter_response
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
LIMIT 5;

-- ✅ Expected: profile_name should show actual names (not null)
-- ❌ If profile_name is null: Profiles don't have full_name

-- ============================================
-- TEST 6: Check RLS policies
-- ============================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual::text as condition
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY cmd, policyname;

-- ✅ Expected: At least one SELECT policy with permissive condition
-- ❌ If no SELECT policy: Add one with USING (true)

-- ============================================
-- INTERPRETATION OF RESULTS
-- ============================================

/*
SCENARIO A: All tests pass, Flutter still shows "Unknown User"
→ Problem: Flutter app is using cached code
→ Fix: Run `flutter clean` then `flutter run`

SCENARIO B: TEST 1 fails (no vehicles)
→ Problem: No vehicles in database
→ Fix: Create vehicles first

SCENARIO C: TEST 2 fails (profiles without names)
→ Problem: Profiles exist but don't have full_name
→ Fix: Run the UPDATE query below

SCENARIO D: TEST 3 shows NULL owner_name
→ Problem: Same as SCENARIO C
→ Fix: Run the UPDATE query below

SCENARIO E: TEST 6 shows no SELECT policy
→ Problem: RLS is blocking reads
→ Fix: Run the CREATE POLICY query below
*/

-- ============================================
-- FIX: Update profiles without names
-- ============================================

-- First, check which profiles need names:
SELECT 
    id,
    email,
    full_name,
    CASE 
        WHEN full_name IS NULL OR full_name = '' THEN 'NEEDS UPDATE'
        ELSE 'OK'
    END as status
FROM profiles
ORDER BY created_at DESC;

-- If any show 'NEEDS UPDATE', run this:
-- UPDATE profiles
-- SET full_name = COALESCE(
--     NULLIF(full_name, ''),  -- Keep existing name if not empty
--     email,                   -- Use email if no name
--     'User ' || substring(id, 1, 8)  -- Fallback to User + ID
-- )
-- WHERE full_name IS NULL OR full_name = '';

-- Verify the update:
-- SELECT id, email, full_name FROM profiles;

-- ============================================
-- FIX: Add permissive RLS policy
-- ============================================

-- Drop existing policies
-- DROP POLICY IF EXISTS "Allow all SELECT on vehicles" ON vehicles;

-- Create new permissive policy
-- CREATE POLICY "Allow all SELECT on vehicles"
-- ON vehicles
-- FOR SELECT
-- TO authenticated, anon
-- USING (true);

-- Verify policy was created:
-- SELECT policyname, cmd, qual::text
-- FROM pg_policies
-- WHERE tablename = 'vehicles' AND cmd = 'SELECT';

-- ============================================
-- FINAL VERIFICATION
-- ============================================

-- After running all fixes, this should return vehicles with names:
SELECT 
    v.id,
    v.vehicle_name,
    p.full_name as owner_name,
    v.is_online,
    CASE 
        WHEN p.full_name IS NOT NULL AND p.full_name != '' THEN '✅ HAS NAME'
        ELSE '❌ NO NAME'
    END as status
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
ORDER BY v.created_at DESC
LIMIT 10;

-- ✅ All rows should show '✅ HAS NAME'
-- ❌ If any show '❌ NO NAME', run the UPDATE query above

-- ============================================
-- SUCCESS CRITERIA
-- ============================================

/*
✅ TEST 1: total_vehicles > 0, online_vehicles > 0
✅ TEST 2: profiles_with_names > 0, profiles_without_names = 0
✅ TEST 3: owner_name shows actual names (not NULL)
✅ TEST 4: status = '✅ Profile has name'
✅ TEST 5: profile_name shows actual names (not null)
✅ TEST 6: At least one SELECT policy exists
✅ FINAL VERIFICATION: All rows show '✅ HAS NAME'

If all tests pass:
→ Rebuild Flutter app: `flutter clean` then `flutter run`
→ Check logs: Should see "✅ Loaded X vehicles" with X > 0
→ Check UI: Should see actual user names (not "Unknown User")
*/
