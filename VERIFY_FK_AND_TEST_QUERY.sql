-- ============================================
-- VERIFY FOREIGN KEY NAME AND TEST QUERY
-- ============================================

-- 1. Check the actual FK constraint name
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'vehicles'
    AND ccu.table_name = 'profiles';

-- Expected result: vehicles_new_profile_id_fkey

-- ============================================
-- 2. Test the exact query that Flutter is using
-- ============================================

-- This should work if FK name is correct:
SELECT 
    vehicles.*,
    profiles.full_name,
    profiles.profile_photo_url
FROM vehicles
LEFT JOIN profiles ON vehicles.profile_id = profiles.id
WHERE vehicles.is_online = true
ORDER BY vehicles.created_at DESC;

-- ============================================
-- 3. Test PostgREST-style query (what Supabase uses)
-- ============================================

-- Run this in Supabase SQL Editor to simulate the Flutter query:
-- This is what the Dart code translates to:

/*
GET /rest/v1/vehicles?select=*,profiles!vehicles_new_profile_id_fkey(full_name,profile_photo_url)&is_online=eq.true&order=created_at.desc
*/

-- To test if RLS is blocking:
-- Temporarily disable RLS on vehicles table:
ALTER TABLE vehicles DISABLE ROW LEVEL SECURITY;

-- Then try the query again from Flutter
-- If it works, the issue is RLS policy

-- Re-enable RLS after testing:
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. Check current RLS policies on vehicles
-- ============================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'vehicles';

-- ============================================
-- 5. Create a permissive SELECT policy for testing
-- ============================================

-- Drop existing SELECT policies
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON vehicles;
DROP POLICY IF EXISTS "Public can view online vehicles" ON vehicles;
DROP POLICY IF EXISTS "Anyone can view vehicles" ON vehicles;

-- Create a simple, permissive policy
CREATE POLICY "Allow all SELECT on vehicles"
ON vehicles
FOR SELECT
TO authenticated, anon
USING (true);

-- ============================================
-- 6. Verify the policy was created
-- ============================================

SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'vehicles' AND cmd = 'SELECT';

-- Expected: "Allow all SELECT on vehicles" with qual = true
