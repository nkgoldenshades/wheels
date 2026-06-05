-- Check current authentication configuration
-- Run this to see what auth.uid() returns

-- 1. Check if Firebase JWT is configured
SELECT * FROM auth.config;

-- 2. Test what auth.uid() returns (run this while logged in)
SELECT 
  auth.uid() as current_user_id,
  auth.role() as current_role,
  auth.jwt() as current_jwt;

-- 3. Check existing trip_media policies
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects' 
  AND policyname LIKE '%trip_media%';
