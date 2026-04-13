-- QUICK FIX: Allow guests to read posts and vehicles
-- Run this in Supabase SQL Editor NOW

-- 1. Allow ANYONE (including guests) to read active posts
DROP POLICY IF EXISTS "Allow public read access to active posts" ON posts;
CREATE POLICY "Allow public read access to active posts"
ON posts FOR SELECT
TO public
USING (is_active = true);

-- 2. Allow ANYONE (including guests) to read online vehicles  
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON vehicles;
CREATE POLICY "Allow public read access to online vehicles"
ON vehicles FOR SELECT
TO public
USING (is_online = true);

-- 3. Allow ANYONE to read profile names (for provider display)
DROP POLICY IF EXISTS "Allow public read access to profile names" ON profiles;
CREATE POLICY "Allow public read access to profile names"
ON profiles FOR SELECT
TO public
USING (true);

-- VERIFY: Check if policies are created
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE tablename IN ('posts', 'vehicles', 'profiles')
AND cmd = 'SELECT';

-- TEST: Try reading as guest (should work now)
SELECT COUNT(*) as active_posts FROM posts WHERE is_active = true;
SELECT COUNT(*) as online_vehicles FROM vehicles WHERE is_online = true;
SELECT COUNT(*) as profiles FROM profiles;
