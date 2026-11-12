-- 🧪 VERIFY PROFILES TABLE FIX
-- Run this in Supabase SQL Editor to confirm everything is working

-- 1. Check if profiles table exists with correct structure
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_name = 'profiles'
AND column_name IN ('id', 'full_name', 'email', 'phone_number', 'profile_photo_url', 'business_type')
ORDER BY ordinal_position;

-- 2. Check RLS policies are correct
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%auth.jwt()%' THEN '✅ Uses Firebase JWT'
    ELSE '❌ Wrong policy'
  END as policy_status
FROM pg_policies 
WHERE tablename = 'profiles';

-- 3. Test JWT function
SELECT get_jwt_claims() as jwt_test;

-- Expected results:
-- ✅ profiles table with correct columns
-- ✅ RLS policies using auth.jwt()->>'sub'
-- ✅ JWT function working