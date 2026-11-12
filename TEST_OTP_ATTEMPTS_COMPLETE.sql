-- ============================================
-- COMPLETE OTP ATTEMPTS DEBUGGING TEST
-- ============================================
-- This file tests why otp_attempts is not incrementing
-- Run each section step-by-step and paste results
-- ============================================

-- ============================================
-- STEP 1: Verify function exists and signature
-- ============================================
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as parameters,
  pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'verify_otp';

-- Expected output:
-- function_name | parameters                                                    | return_type
-- verify_otp    | p_booking_id bigint, p_profile_customer_id text, p_entered_otp text | text


-- ============================================
-- STEP 2: Check bookings table structure
-- ============================================
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'bookings'
  AND column_name IN ('id', 'otp_code', 'otp_attempts', 'otp_locked', 'otp_verified', 'profile_customer_id')
ORDER BY ordinal_position;

-- Expected: id should be BIGINT, otp_attempts should be INTEGER


-- ============================================
-- STEP 3: Create a test booking
-- ============================================
INSERT INTO public.bookings (
  profile_customer_id,
  profile_provider_id,
  post_id,
  status,
  service_type,
  total_price,
  price_snapshot,
  deposit_snapshot,
  currency_snapshot,
  persons_snapshot,
  booking_strategy_snapshot,
  post_mode,
  start_time,
  end_time,
  otp_code
) VALUES (
  'test-user-debug-attempts',
  'test-provider-debug',
  (SELECT id FROM public.posts ORDER BY created_at DESC LIMIT 1),
  'pending',
  'passenger',
  100.00,
  100.00,
  0.00,
  'INR',
  1,
  'instant',
  'instant',
  NOW(),
  NOW() + INTERVAL '1 hour',
  NULL  -- Let trigger generate OTP
) RETURNING id, otp_code, otp_attempts, otp_locked, otp_verified;

-- Expected: Should return a row with otp_code (6 digits), otp_attempts = 0


-- ============================================
-- STEP 4: Get the booking ID for testing
-- ============================================
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified,
  profile_customer_id
FROM public.bookings
WHERE profile_customer_id = 'test-user-debug-attempts'
ORDER BY created_at DESC
LIMIT 1;

-- Copy the 'id' value from this result for next steps


-- ============================================
-- STEP 5: Test verify_otp with WRONG OTP (attempt 1)
-- ============================================
-- Replace <BOOKING_ID> with actual ID from Step 4
SELECT verify_otp(
  <BOOKING_ID>,  -- Replace with actual booking ID (e.g., 23)
  'test-user-debug-attempts',
  '999999'  -- Wrong OTP
) as result;

-- Expected result: 'wrong_otp'


-- ============================================
-- STEP 6: Check if otp_attempts incremented to 1
-- ============================================
SELECT 
  id,
  otp_code,
  otp_attempts,  -- Should be 1 now
  otp_locked,    -- Should be false
  otp_verified   -- Should be false
FROM public.bookings
WHERE profile_customer_id = 'test-user-debug-attempts'
ORDER BY created_at DESC
LIMIT 1;

-- Expected: otp_attempts = 1


-- ============================================
-- STEP 7: Test verify_otp with WRONG OTP (attempt 2)
-- ============================================
SELECT verify_otp(
  <BOOKING_ID>,  -- Replace with actual booking ID
  'test-user-debug-attempts',
  '888888'  -- Wrong OTP
) as result;

-- Expected result: 'wrong_otp'


-- ============================================
-- STEP 8: Check if otp_attempts incremented to 2
-- ============================================
SELECT 
  id,
  otp_code,
  otp_attempts,  -- Should be 2 now
  otp_locked,    -- Should be false
  otp_verified   -- Should be false
FROM public.bookings
WHERE profile_customer_id = 'test-user-debug-attempts'
ORDER BY created_at DESC
LIMIT 1;

-- Expected: otp_attempts = 2


-- ============================================
-- STEP 9: Test 3 more wrong attempts (total 5)
-- ============================================
SELECT verify_otp(<BOOKING_ID>, 'test-user-debug-attempts', '777777') as attempt_3;
SELECT verify_otp(<BOOKING_ID>, 'test-user-debug-attempts', '666666') as attempt_4;
SELECT verify_otp(<BOOKING_ID>, 'test-user-debug-attempts', '555555') as attempt_5;

-- Expected: All should return 'wrong_otp'


-- ============================================
-- STEP 10: Check if locked after 5 attempts
-- ============================================
SELECT 
  id,
  otp_code,
  otp_attempts,  -- Should be 5 now
  otp_locked,    -- Should be TRUE
  otp_verified   -- Should be false
FROM public.bookings
WHERE profile_customer_id = 'test-user-debug-attempts'
ORDER BY created_at DESC
LIMIT 1;

-- Expected: otp_attempts = 5, otp_locked = true


-- ============================================
-- STEP 11: Try verifying after locked
-- ============================================
SELECT verify_otp(
  <BOOKING_ID>,
  'test-user-debug-attempts',
  (SELECT otp_code FROM bookings WHERE id = <BOOKING_ID>)  -- Correct OTP
) as result;

-- Expected result: 'locked' (not 'success')


-- ============================================
-- STEP 12: Check RLS policies on bookings table
-- ============================================
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
WHERE tablename = 'bookings';

-- Check if there's a policy blocking UPDATE operations


-- ============================================
-- STEP 13: Test direct UPDATE (bypass function)
-- ============================================
-- This tests if UPDATE works at all
UPDATE public.bookings
SET otp_attempts = 99
WHERE profile_customer_id = 'test-user-debug-attempts';

-- Check if it updated
SELECT id, otp_attempts
FROM public.bookings
WHERE profile_customer_id = 'test-user-debug-attempts';

-- If otp_attempts is still not 99, there's an RLS policy blocking UPDATE


-- ============================================
-- STEP 14: Check function permissions
-- ============================================
SELECT 
  routine_name,
  routine_type,
  security_type,
  specific_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'verify_otp';

-- Expected: security_type should be 'DEFINER' (SECURITY DEFINER)


-- ============================================
-- STEP 15: View the actual function code
-- ============================================
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'verify_otp';

-- This shows the actual function code - check if UPDATE statement is correct


-- ============================================
-- CLEANUP (run after debugging)
-- ============================================
-- DELETE FROM public.bookings WHERE profile_customer_id = 'test-user-debug-attempts';


-- ============================================
-- TROUBLESHOOTING GUIDE
-- ============================================
-- If otp_attempts is NOT incrementing:
--
-- 1. Check Step 6 result:
--    - If otp_attempts is still 0, the UPDATE is not executing
--    - Check Step 12 for RLS policies blocking UPDATE
--    - Check Step 15 to verify function code is correct
--
-- 2. Check Step 13 result:
--    - If direct UPDATE fails, RLS policy is blocking
--    - Solution: Add RLS policy to allow UPDATE on bookings
--
-- 3. Check Step 14 result:
--    - If security_type is NOT 'DEFINER', function doesn't bypass RLS
--    - Solution: Recreate function with SECURITY DEFINER
--
-- 4. Check Step 15 result:
--    - Verify UPDATE statement uses correct column names
--    - Verify WHERE clause uses correct booking ID
--
-- 5. If all above pass but Flutter still fails:
--    - Check Flutter logs for actual booking ID being sent
--    - Verify booking ID type matches (BIGINT vs TEXT)
--    - Check if Flutter is calling the function at all
-- ============================================
