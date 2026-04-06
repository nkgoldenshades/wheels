-- 🔍 DEBUG PROFILES TABLE
-- Run these queries in Supabase SQL Editor to debug

-- 1. Check if profiles table exists
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check RLS policies
SELECT policyname, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- 3. Test JWT function (should work if you ran fresh_database_setup.sql)
SELECT get_jwt_claims();

-- 4. Check current JWT claims
SELECT 
  auth.jwt() as full_jwt,
  auth.jwt()->>'sub' as firebase_uid,
  auth.jwt()->>'role' as role;

-- 5. Try to insert a test profile (replace 'test-uid' with real Firebase UID)
INSERT INTO profiles (
  id, 
  full_name, 
  email, 
  business_type
) VALUES (
  'test-uid-123',
  'Test User',
  'test@example.com',
  'solo'
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  updated_at = now();

-- 6. Check if any profiles exist
SELECT COUNT(*) as profile_count FROM profiles;

-- 7. See all profiles (if any)
SELECT id, full_name, email, business_type, created_at 
FROM profiles 
LIMIT 5;