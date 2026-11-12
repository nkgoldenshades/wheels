-- ============================================
-- SIMPLE DIAGNOSTIC: Why "Unknown User"?
-- ============================================
-- Run this in Supabase SQL Editor to diagnose the issue

-- ============================================
-- TEST 1: Do vehicles exist?
-- ============================================
SELECT 
    COUNT(*) as total_vehicles,
    COUNT(CASE WHEN is_online = true THEN 1 END) as online_vehicles
FROM vehicles;

-- Expected: total_vehicles > 0, online_vehicles > 0
-- If 0: No vehicles in database

-- ============================================
-- TEST 2: Do profiles have names?
-- ============================================
SELECT 
    id,
    full_name,
    email,
    created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 5;

-- Expected: full_name should NOT be NULL
-- If NULL: Profiles exist but don't have names

-- ============================================
-- TEST 3: Can we join vehicles with profiles?
-- ============================================
SELECT 
    v.id as vehicle_id,
    v.vehicle_name,
    v.profile_id,
    p.full_name as owner_name,
    p.email as owner_email,
    v.is_online
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
ORDER BY v.created_at DESC
LIMIT 5;

-- Expected: owner_name should show actual names (not NULL)
-- If NULL: Join is working but profiles don't have full_name

-- ============================================
-- TEST 4: Check FK constraint name
-- ============================================
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'vehicles'
    AND ccu.table_name = 'profiles';

-- Expected: constraint_name = 'vehicles_new_profile_id_fkey'
-- If different: FK name doesn't match what Flutter expects

-- ============================================
-- TEST 5: Check RLS policies on vehicles
-- ============================================
SELECT 
    policyname,
    cmd,
    qual::text as condition
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY cmd, policyname;

-- Expected: At least one SELECT policy with permissive condition
-- If no SELECT policy: RLS is blocking reads

-- ============================================
-- TEST 6: Simulate PostgREST query
-- ============================================
-- This is what the Flutter app is trying to do:
SELECT 
    json_build_object(
        'id', v.id,
        'vehicle_name', v.vehicle_name,
        'profile_id', v.profile_id,
        'is_online', v.is_online,
        'profiles', json_build_object(
            'full_name', p.full_name,
            'profile_photo_url', p.profile_photo_url
        )
    ) as postgrest_response
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
LIMIT 1;

-- Expected: Should return JSON with full_name populated
-- If full_name is NULL: Profiles don't have names

-- ============================================
-- RESULTS INTERPRETATION
-- ============================================

/*
SCENARIO 1: TEST 1 returns 0 vehicles
→ Problem: No vehicles in database
→ Fix: Create vehicles first

SCENARIO 2: TEST 2 shows NULL full_name
→ Problem: Profiles exist but don't have names
→ Fix: Update profiles to add full_name

SCENARIO 3: TEST 3 shows NULL owner_name
→ Problem: Join works but profiles.full_name is NULL
→ Fix: Same as SCENARIO 2

SCENARIO 4: TEST 4 shows different FK name
→ Problem: FK constraint name doesn't match Flutter code
→ Fix: Either rename FK or update Flutter code

SCENARIO 5: TEST 5 shows no SELECT policy
→ Problem: RLS is blocking all reads
→ Fix: Add permissive SELECT policy

SCENARIO 6: All tests pass but still "Unknown User"
→ Problem: Flutter app is using cached code
→ Fix: Run `flutter clean` then `flutter run`
*/

-- ============================================
-- QUICK FIX: Add permissive RLS policy
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all SELECT on vehicles" ON vehicles;
DROP POLICY IF EXISTS "Public can view online vehicles" ON vehicles;
DROP POLICY IF EXISTS "Anyone can view vehicles" ON vehicles;

-- Create simple, permissive policy
CREATE POLICY "Allow all SELECT on vehicles"
ON vehicles
FOR SELECT
TO authenticated, anon
USING (true);

-- Verify policy was created
SELECT policyname, cmd, qual::text
FROM pg_policies
WHERE tablename = 'vehicles' AND cmd = 'SELECT';

-- ============================================
-- QUICK FIX: Update profiles with names
-- ============================================

-- Check if profiles need names
SELECT 
    COUNT(*) as profiles_without_names
FROM profiles
WHERE full_name IS NULL OR full_name = '';

-- If > 0, update them:
-- UPDATE profiles
-- SET full_name = COALESCE(email, 'User ' || substring(id, 1, 8))
-- WHERE full_name IS NULL OR full_name = '';

-- ============================================
-- FINAL CHECK
-- ============================================

-- After running fixes, this should return vehicles with names:
SELECT 
    v.id,
    v.vehicle_name,
    p.full_name as owner_name,
    v.is_online
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE v.is_online = true
LIMIT 5;

-- Expected: owner_name should show actual names (not NULL)
