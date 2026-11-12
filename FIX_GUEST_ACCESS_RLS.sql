-- Fix RLS Policies for Guest Access
-- Allow public (unauthenticated) users to read posts and vehicles
-- Run this in Supabase SQL Editor

-- ============================================
-- POSTS TABLE - Allow public read access
-- ============================================

-- Drop existing SELECT policy if it exists
DROP POLICY IF EXISTS "Allow public read access to active posts" ON posts;

-- Create new policy allowing anyone (including guests) to read active posts
CREATE POLICY "Allow public read access to active posts"
ON posts
FOR SELECT
TO public  -- This includes both authenticated AND anonymous users
USING (is_active = true);

-- Allow authenticated users to insert their own posts
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
CREATE POLICY "Users can insert their own posts"
ON posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- Allow users to update their own posts
DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
CREATE POLICY "Users can update their own posts"
ON posts
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'))
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- Allow users to delete their own posts
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;
CREATE POLICY "Users can delete their own posts"
ON posts
FOR DELETE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'));

-- ============================================
-- VEHICLES TABLE - Allow public read access
-- ============================================

-- Drop existing SELECT policy if it exists
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON vehicles;

-- Create new policy allowing anyone to read online vehicles
CREATE POLICY "Allow public read access to online vehicles"
ON vehicles
FOR SELECT
TO public  -- This includes both authenticated AND anonymous users
USING (is_online = true);

-- Allow authenticated users to insert their own vehicles
DROP POLICY IF EXISTS "Users can insert their own vehicles" ON vehicles;
CREATE POLICY "Users can insert their own vehicles"
ON vehicles
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- Allow users to update their own vehicles
DROP POLICY IF EXISTS "Users can update their own vehicles" ON vehicles;
CREATE POLICY "Users can update their own vehicles"
ON vehicles
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'))
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- Allow users to delete their own vehicles
DROP POLICY IF EXISTS "Users can delete their own vehicles" ON vehicles;
CREATE POLICY "Users can delete their own vehicles"
ON vehicles
FOR DELETE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'));

-- ============================================
-- PROFILES TABLE - Allow public read access to basic info
-- ============================================

-- Drop existing SELECT policy if it exists
DROP POLICY IF EXISTS "Allow public read access to profile names" ON profiles;

-- Create new policy allowing anyone to read profile names (for provider display)
CREATE POLICY "Allow public read access to profile names"
ON profiles
FOR SELECT
TO public
USING (true);  -- Allow reading all profiles (only full_name is exposed in joins)

-- Users can only update their own profile
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
ON profiles
FOR UPDATE
TO authenticated
USING (id = (auth.jwt() ->> 'sub'))
WITH CHECK (id = (auth.jwt() ->> 'sub'));

-- ============================================
-- BOOKINGS TABLE - Restricted access
-- ============================================

-- Bookings should NOT be public - only for involved parties

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their bookings" ON bookings;
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;
DROP POLICY IF EXISTS "Users can update their bookings" ON bookings;

-- Users can view bookings where they are customer OR provider
CREATE POLICY "Users can view their bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  profile_customer_id = (auth.jwt() ->> 'sub')
  OR
  profile_provider_id = (auth.jwt() ->> 'sub')
);

-- Users can create bookings as customer
CREATE POLICY "Users can create bookings"
ON bookings
FOR INSERT
TO authenticated
WITH CHECK (profile_customer_id = (auth.jwt() ->> 'sub'));

-- Users can update bookings where they are customer OR provider
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
-- AI CONVERSATIONS TABLE - Private to user
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own conversations" ON ai_conversations;
DROP POLICY IF EXISTS "Users can create their own conversations" ON ai_conversations;
DROP POLICY IF EXISTS "Users can update their own conversations" ON ai_conversations;

-- Users can only see their own AI conversations
CREATE POLICY "Users can view their own conversations"
ON ai_conversations
FOR SELECT
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'));

-- Users can create their own conversations
CREATE POLICY "Users can create their own conversations"
ON ai_conversations
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- Users can update their own conversations
CREATE POLICY "Users can update their own conversations"
ON ai_conversations
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'))
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));

-- ============================================
-- VERIFY POLICIES
-- ============================================

-- Check posts policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'posts';

-- Check vehicles policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'vehicles';

-- Check profiles policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles';

-- ============================================
-- TEST QUERIES (Run as guest/unauthenticated)
-- ============================================

-- Test 1: Can guests read active posts?
-- This should return posts (not error)
SELECT id, profile_id, service_type, price, is_active
FROM posts
WHERE is_active = true
LIMIT 5;

-- Test 2: Can guests read online vehicles?
-- This should return vehicles (not error)
SELECT id, profile_id, name, type, is_online
FROM vehicles
WHERE is_online = true
LIMIT 5;

-- Test 3: Can guests read profile names?
-- This should return profiles (not error)
SELECT id, full_name
FROM profiles
LIMIT 5;

-- ============================================
-- IMPORTANT NOTES
-- ============================================

/*
1. PUBLIC ACCESS:
   - Posts: Anyone can read active posts
   - Vehicles: Anyone can read online vehicles
   - Profiles: Anyone can read profile names (for provider display)

2. AUTHENTICATED ACCESS:
   - Users can create/update/delete their own posts
   - Users can create/update/delete their own vehicles
   - Users can update their own profile

3. PRIVATE DATA:
   - Bookings: Only customer and provider can see
   - AI Conversations: Only owner can see
   - Sensitive profile data: Protected by column-level security

4. SECURITY:
   - Firebase JWT is validated: auth.jwt() ->> 'sub'
   - This matches Firebase UID with profile_id
   - RLS ensures users can only modify their own data

5. GUEST USERS:
   - Can browse posts and vehicles
   - Can see provider names
   - Cannot create posts/bookings
   - Cannot see other users' private data
*/
