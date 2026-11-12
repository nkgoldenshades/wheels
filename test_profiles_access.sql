-- 🧪 TEST PROFILES TABLE ACCESS
-- Run this in Supabase SQL Editor to test table access

-- 1. Test basic table access (should work as admin)
SELECT COUNT(*) as profile_count FROM profiles;

-- 2. Test table structure
\d profiles;

-- 3. Test RLS policies
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'profiles';

-- 4. Test JWT claims (run this when logged in with Firebase)
SELECT 
  auth.jwt() as full_jwt,
  auth.jwt()->>'sub' as firebase_uid,
  auth.jwt()->>'role' as user_role;

-- 5. Test manual insert with your Firebase UID (replace 'YOUR_FIREBASE_UID')
INSERT INTO profiles (
  id,
  full_name,
  email,
  business_type
) VALUES (
  'YOUR_FIREBASE_UID_HERE',
  'Test User',
  'test@example.com',
  'solo'
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  updated_at = now();

-- 6. Check if insert worked
SELECT * FROM profiles;