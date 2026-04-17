-- ============================================
-- QUICK FIX: Allow anon users to read profiles
-- ============================================
-- This fixes "Unknown User" if RLS is blocking guest access

-- Enable RLS on profiles (if not already enabled)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop any restrictive policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users only" ON profiles;
DROP POLICY IF EXISTS "Allow authenticated to read profiles" ON profiles;

-- Create permissive policy for all users (including anon/guest)
CREATE POLICY "Allow all to read profiles"
ON profiles
FOR SELECT
TO authenticated, anon
USING (true);

-- Verify policy was created
SELECT 
    policyname,
    cmd,
    roles,
    qual::text as condition
FROM pg_policies
WHERE tablename = 'profiles' AND cmd = 'SELECT';

-- Expected output:
-- policyname: "Allow all to read profiles"
-- cmd: SELECT
-- roles: {authenticated,anon}
-- condition: true

-- ============================================
-- Test the fix
-- ============================================

-- This should now return profiles:
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

-- ============================================
-- IMPORTANT NOTES
-- ============================================

/*
✅ This is SAFE because:
- Profiles table should only contain public info (name, avatar)
- Sensitive data (email, phone) should be in a separate table with stricter RLS
- Users can only UPDATE/DELETE their own profile (separate policies)

⚠️ If your profiles table contains sensitive data:
- Move sensitive fields to a separate table (e.g., profiles_private)
- Apply stricter RLS to that table
- Keep profiles table for public info only
*/
