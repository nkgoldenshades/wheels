-- ============================================
-- DEBUG: Why Vehicles Not Loading in App
-- ============================================

-- 1. Check if vehicles exist
SELECT COUNT(*) as total_vehicles FROM vehicles;

-- 2. Check your specific vehicles
SELECT 
  id,
  profile_id,
  registration_number,
  is_active,
  is_online,
  is_verified
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1'
LIMIT 10;

-- 3. Check RLS status
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'vehicles';

-- 4. Check RLS policies
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

-- 5. Test the exact query the app uses
SELECT * 
FROM vehicles 
WHERE is_active = true 
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- FIX: Create Proper RLS Policy
-- ============================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Enable read access for all users" ON vehicles;
DROP POLICY IF EXISTS "Users can view all vehicles" ON vehicles;
DROP POLICY IF EXISTS "Users can view their own vehicles" ON vehicles;
DROP POLICY IF EXISTS "Allow public read access" ON vehicles;

-- Create new policy that allows everyone to view all vehicles
CREATE POLICY "public_read_vehicles" 
ON vehicles 
FOR SELECT 
USING (true);

-- Allow users to insert their own vehicles
DROP POLICY IF EXISTS "Users can insert their own vehicles" ON vehicles;
CREATE POLICY "users_insert_own_vehicles" 
ON vehicles 
FOR INSERT 
WITH CHECK (auth.uid() = profile_id);

-- Allow users to update their own vehicles
DROP POLICY IF EXISTS "Users can update their own vehicles" ON vehicles;
CREATE POLICY "users_update_own_vehicles" 
ON vehicles 
FOR UPDATE 
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- Allow users to delete their own vehicles
DROP POLICY IF EXISTS "Users can delete their own vehicles" ON vehicles;
CREATE POLICY "users_delete_own_vehicles" 
ON vehicles 
FOR DELETE 
USING (auth.uid() = profile_id);

-- ============================================
-- VERIFY: Check if policies are active
-- ============================================
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'vehicles';

-- ============================================
-- TEST: Simulate app query
-- ============================================
-- This should return vehicles if RLS is fixed
SELECT 
  id,
  profile_id,
  registration_number,
  vehicle_type,
  is_active,
  is_online
FROM vehicles 
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 10;
