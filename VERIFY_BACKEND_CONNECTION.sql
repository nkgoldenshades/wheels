-- ============================================
-- VERIFY BACKEND OTP SYSTEM IS CONNECTED
-- ============================================

-- 1. Check if functions exist and are executable
SELECT '=== STEP 1: Check Functions ===' as step;
SELECT 
  proname as function_name,
  prosecdef as is_security_definer,
  provolatile as volatility,
  pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp')
ORDER BY proname;

-- Expected: 3 rows (generate_otp, set_booking_otp, verify_otp)

-- 2. Check if trigger exists and is enabled
SELECT '=== STEP 2: Check Trigger ===' as step;
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  tgrelid::regclass as table_name,
  tgtype as trigger_type
FROM pg_trigger 
WHERE tgname = 'booking_otp_trigger';

-- Expected: 1 row (booking_otp_trigger, enabled='O' means enabled)

-- 3. Test OTP generation function directly
SELECT '=== STEP 3: Test OTP Generation ===' as step;
SELECT 
  generate_otp() as test_otp_1,
  generate_otp() as test_otp_2,
  generate_otp() as test_otp_3;

-- Expected: 3 different 6-digit OTPs

-- 4. Check permissions on verify_otp function
SELECT '=== STEP 4: Check Permissions ===' as step;
SELECT 
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'verify_otp'
  AND routine_schema = 'public';

-- Expected: anon and authenticated have EXECUTE permission

-- 5. Test trigger on actual INSERT
SELECT '=== STEP 5: Test Trigger on INSERT ===' as step;
INSERT INTO public.bookings (
  profile_customer_id,
  profile_provider_id,
  post_id,
  status,
  service_type,
  total_price,
  price_snapshot,
  start_time,
  end_time,
  otp_code
) VALUES (
  'verify-test-user',
  'verify-test-provider',
  (SELECT id FROM public.posts ORDER BY created_at DESC LIMIT 1),
  'pending',
  'passenger',
  100.00,
  100.00,
  NOW(),
  NOW() + INTERVAL '1 hour',
  NULL
) RETURNING 
  id as booking_id,
  otp_code,
  LENGTH(otp_code) as otp_length,
  otp_attempts,
  otp_locked,
  otp_verified;

-- Expected: Returns booking with 6-digit otp_code

-- 6. Test verify_otp function with wrong OTP
SELECT '=== STEP 6: Test Wrong OTP ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'verify-test-user' ORDER BY created_at DESC LIMIT 1),
  'verify-test-user',
  '999999'
) as verification_result;

-- Expected: 'wrong_otp'

-- 7. Check attempts incremented
SELECT '=== STEP 7: Check Attempts Incremented ===' as step;
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified
FROM public.bookings
WHERE profile_customer_id = 'verify-test-user'
ORDER BY created_at DESC
LIMIT 1;

-- Expected: otp_attempts = 1

-- 8. Test verify_otp with correct OTP
SELECT '=== STEP 8: Test Correct OTP ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'verify-test-user' ORDER BY created_at DESC LIMIT 1),
  'verify-test-user',
  (SELECT otp_code FROM bookings WHERE profile_customer_id = 'verify-test-user' ORDER BY created_at DESC LIMIT 1)
) as verification_result;

-- Expected: 'success'

-- 9. Check verified status
SELECT '=== STEP 9: Check Verified Status ===' as step;
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified,
  otp_verified_at
FROM public.bookings
WHERE profile_customer_id = 'verify-test-user'
ORDER BY created_at DESC
LIMIT 1;

-- Expected: otp_verified = true, otp_attempts = NULL

-- 10. Cleanup test data
SELECT '=== STEP 10: Cleanup ===' as step;
DELETE FROM public.bookings WHERE profile_customer_id = 'verify-test-user';

-- ============================================
-- SUMMARY OF EXPECTED RESULTS
-- ============================================
-- Step 1: ✅ 3 functions exist
-- Step 2: ✅ 1 trigger exists and enabled
-- Step 3: ✅ 3 different 6-digit OTPs generated
-- Step 4: ✅ anon and authenticated have EXECUTE permission
-- Step 5: ✅ Booking created with 6-digit OTP
-- Step 6: ✅ Returns 'wrong_otp'
-- Step 7: ✅ otp_attempts = 1
-- Step 8: ✅ Returns 'success'
-- Step 9: ✅ otp_verified = true, otp_attempts = NULL
-- Step 10: ✅ Test data deleted
-- ============================================
