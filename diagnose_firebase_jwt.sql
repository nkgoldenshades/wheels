-- Diagnose Firebase JWT authentication issue

-- Test 1: Check what auth.jwt() returns
SELECT 
  auth.uid() as user_id,
  auth.role() as user_role,
  auth.jwt()->>'sub' as jwt_sub,
  auth.jwt()->>'iss' as jwt_issuer,
  auth.jwt()->>'aud' as jwt_audience;

-- Test 2: Check if your user exists in bookings
SELECT 
  id,
  profile_customer_id,
  profile_provider_id,
  status
FROM public.bookings
WHERE profile_customer_id = 'JgBbKBwgXpTBkttVNryBMCIco172'
   OR profile_provider_id = 'JgBbKBwgXpTBkttVNryBMCIco172'
LIMIT 5;

-- Test 3: Check current trip_media policies
SELECT 
  policyname,
  cmd,
  roles,
  with_check::text
FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE '%trip_media%';
