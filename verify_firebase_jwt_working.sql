-- 🧪 QUICK DEBUG TEST
-- Run this in Supabase SQL Editor to verify Firebase JWT is working

-- Test 1: Check if JWT is being received
SELECT 
  'JWT Status' as test,
  CASE 
    WHEN auth.jwt() IS NULL THEN '❌ No JWT received'
    ELSE '✅ JWT received'
  END as result;

-- Test 2: Check Firebase UID
SELECT 
  'Firebase UID' as test,
  CASE 
    WHEN auth.jwt()->>'sub' IS NULL THEN '❌ No Firebase UID'
    ELSE '✅ UID: ' || auth.jwt()->>'sub'
  END as result;

-- Test 3: Check role
SELECT 
  'Auth Role' as test,
  CASE 
    WHEN auth.jwt()->>'role' IS NULL THEN '❌ No role'
    ELSE '✅ Role: ' || auth.jwt()->>'role'
  END as result;

-- Test 4: Full JWT content (for debugging)
SELECT 
  'Full JWT' as test,
  COALESCE(auth.jwt()::text, '❌ NULL JWT') as result;