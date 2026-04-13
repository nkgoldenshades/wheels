-- COMPLETE FIX: Secure guest access with public view
-- This is the BEST approach - exposes only what's needed
-- Run this in Supabase SQL Editor

-- ============================================
-- STEP 1: Create public_profiles view
-- ============================================

-- Create view with only public information
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
    id,
    full_name,
    profile_photo_url as avatar_url
FROM profiles;

-- Grant access to the view
GRANT SELECT ON public_profiles TO anon;
GRANT SELECT ON public_profiles TO authenticated;

-- Make it a security barrier (prevents leaking data through view)
ALTER VIEW public_profiles SET (security_barrier = true);

-- ============================================
-- STEP 2: Posts table - Allow public read
-- ============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Allow public read access to active posts" ON posts;

-- Create policy allowing anyone to read active posts
CREATE POLICY "Allow public read access to active posts"
ON posts
FOR SELECT
TO public
USING (is_active = true);

-- Allow authenticated users to manage their own posts
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
CREATE POLICY "Users can insert their own posts"
ON posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
CREATE POLICY "Users can update their own posts"
ON posts
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'))
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;
CREATE POLICY "Users can delete their own posts"
ON posts
FOR DELETE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'));

-- ============================================
-- STEP 3: Vehicles table - Allow public read
-- ============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON vehicles;

-- Create policy allowing anyone to read online vehicles
CREATE POLICY "Allow public read access to online vehicles"
ON vehicles
FOR SELECT
TO public
USING (is_online = true);

-- Allow authenticated users to manage their own vehicles
DROP POLICY IF EXISTS "Users can insert their own vehicles" ON vehicles;
CREATE POLICY "Users can insert their own vehicles"
ON vehicles
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can update their own vehicles" ON vehicles;
CREATE POLICY "Users can update their own vehicles"
ON vehicles
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'))
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can delete their own vehicles" ON vehicles;
CREATE POLICY "Users can delete their own vehicles"
ON vehicles
FOR DELETE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'));

-- ============================================
-- STEP 4: Profiles table - RESTRICT access
-- ============================================

-- IMPORTANT: Keep profiles table PRIVATE
-- Only allow users to read/update their OWN profile

DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
CREATE POLICY "Users can view their own profile"
ON profiles
FOR SELECT
TO authenticated
USING (id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
ON profiles
FOR UPDATE
TO authenticated
USING (id = (auth.jwt() ->> 'sub'))
WITH CHECK (id = (auth.jwt() ->> 'sub'));

-- ============================================
-- STEP 5: Bookings table - Private
-- ============================================

DROP POLICY IF EXISTS "Users can view their bookings" ON bookings;
CREATE POLICY "Users can view their bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  profile_customer_id = (auth.jwt() ->> 'sub')
  OR
  profile_provider_id = (auth.jwt() ->> 'sub')
);

DROP POLICY IF EXISTS "Users can create bookings" ON bookings;
CREATE POLICY "Users can create bookings"
ON bookings
FOR INSERT
TO authenticated
WITH CHECK (profile_customer_id = (auth.jwt() ->> 'sub'));

DROP POLICY IF EXISTS "Users can update their bookings" ON bookings;
CREATE POLICY "Users can update their bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
  profile_customer_id = (auth.jwt() ->> 'sub')
  OR
  profile_provider_id = (auth.jwt() ->> 'sub')
)
WITH CHECK (
  profile_customer_id = (auth.jwt() ->> 'sub')
  OR
  profile_provider_id = (auth.jwt() ->> 'sub')
);

-- ============================================
-- VERIFY SETUP
-- ============================================

-- Check view exists
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_name = 'public_profiles';

-- Check view permissions
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'public_profiles';

-- Check policies
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE tablename IN ('posts', 'vehicles', 'profiles', 'bookings')
ORDER BY tablename, cmd;

-- ============================================
-- TEST QUERIES (as guest/anonymous)
-- ============================================

-- Test 1: Can read public profiles view
SELECT id, full_name, avatar_url 
FROM public_profiles 
LIMIT 5;

-- Test 2: Can read active posts
SELECT id, profile_id, service_type, price 
FROM posts 
WHERE is_active = true 
LIMIT 5;

-- Test 3: Can read online vehicles
SELECT id, profile_id, name, type 
FROM vehicles 
WHERE is_online = true 
LIMIT 5;

-- Test 4: CANNOT read full profiles table (should fail for guests)
-- This should return error or empty for anonymous users
SELECT id, full_name, phone_number, email 
FROM profiles 
LIMIT 5;

-- ============================================
-- SUMMARY
-- ============================================

/*
✅ WHAT'S PUBLIC (guests can see):
   - public_profiles view (id, full_name, avatar_url)
   - Active posts (is_active = true)
   - Online vehicles (is_online = true)

❌ WHAT'S PRIVATE (only owner can see):
   - Full profiles table (phone, email, documents, etc.)
   - Bookings (only customer and provider)
   - AI conversations (only owner)
   - Inactive posts
   - Offline vehicles

🔒 SECURITY:
   - Sensitive data stays in profiles table
   - Only public info exposed via view
   - Users can only modify their own data
   - Firebase JWT validates identity
*/
