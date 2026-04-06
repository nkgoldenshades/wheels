-- 🔍 DEBUG RLS ISSUE
-- Run this in Supabase SQL Editor when logged in with Firebase

-- 1. Check if you can see profiles as admin (should work)
SELECT COUNT(*) as total_profiles FROM profiles;

-- 2. Check your current JWT claims
SELECT 
  auth.jwt() as full_jwt,
  auth.jwt()->>'sub' as firebase_uid,
  auth.jwt()->>'role' as role;

-- 3. Check RLS policies
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- 4. Try to select your own profile (this might fail due to RLS)
-- Replace 'YOUR_FIREBASE_UID' with your actual Firebase UID
SELECT * FROM profiles WHERE id = 'YOUR_FIREBASE_UID';

-- 5. Test if RLS is working correctly
-- This should return your profile if RLS is working
SELECT * FROM profiles WHERE id = auth.jwt()->>'sub';

-- 6. Check if there are any profiles at all
SELECT id, full_name, email, created_at FROM profiles LIMIT 5;