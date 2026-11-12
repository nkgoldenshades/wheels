-- 🧪 TEST SUPABASE CONNECTION
-- Run this in Supabase SQL Editor to verify everything is working

-- 1. Test JWT function exists
SELECT get_jwt_claims() as jwt_test;

-- 2. Check current JWT when logged in
SELECT 
  CASE 
    WHEN auth.jwt() IS NULL THEN '❌ No JWT token'
    ELSE '✅ JWT token present'
  END as jwt_status,
  auth.jwt()->>'sub' as firebase_uid,
  auth.jwt()->>'role' as role;

-- 3. Check profiles table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 4. Check RLS policies are correct
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%auth.jwt()%' THEN '✅ Uses Firebase JWT'
    WHEN qual LIKE '%auth.uid()%' THEN '❌ Uses Supabase auth'
    ELSE '⚠️ Unknown policy'
  END as policy_type
FROM pg_policies 
WHERE tablename = 'profiles';

-- 5. Test manual insert (replace with real Firebase UID)
INSERT INTO profiles (
  id,
  full_name,
  email,
  business_type
) VALUES (
  'manual-test-uid',
  'Manual Test User',
  'test@example.com',
  'solo'
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  updated_at = now();

-- 6. Check if insert worked
SELECT * FROM profiles WHERE id = 'manual-test-uid';