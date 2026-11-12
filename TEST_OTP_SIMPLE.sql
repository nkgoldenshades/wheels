-- ============================================
-- SIMPLE OTP TEST
-- ============================================
-- Run this after installing the trigger and function
-- ============================================

-- Step 1: Check if functions exist
SELECT '=== CHECKING FUNCTIONS ===' as step;
SELECT proname FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp');

-- Step 2: Check if trigger exists
SELECT '=== CHECKING TRIGGER ===' as step;
SELECT tgname FROM pg_trigger WHERE tgname = 'booking_otp_trigger';

-- Step 3: Test OTP auto-generation
SELECT '=== TESTING OTP AUTO-GENERATION ===' as step;
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
  post_mode_snapshot,
  start_time,
  end_time,
  otp_code
) VALUES (
  'test-user-001',
  'test-provider-001',
  gen_random_uuid(),
  'pending',
  'passenger',
  150.00,
  150.00,
  0.00,
  'INR',
  1,
  'instant',
  'instant',
  NOW(),
  NOW() + INTERVAL '2 hours',
  NULL
) RETURNING id, otp_code, otp_attempts, otp_locked, otp_verified;

-- Step 4: Verify OTP was generated (should be 6 digits)
SELECT '=== VERIFYING OTP ===' as step;
SELECT 
  id,
  otp_code,
  LENGTH(otp_code) as otp_length,
  otp_attempts,
  otp_locked,
  otp_verified
FROM public.bookings
WHERE profile_customer_id = 'test-user-001'
ORDER BY created_at DESC
LIMIT 1;

-- Step 5: Test wrong OTP
SELECT '=== TESTING WRONG OTP ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-user-001' ORDER BY created_at DESC LIMIT 1),
  'test-user-001',
  '999999'
) as result;

-- Check attempts incremented
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked
FROM public.bookings
WHERE profile_customer_id = 'test-user-001'
ORDER BY created_at DESC
LIMIT 1;

-- Step 6: Test correct OTP
SELECT '=== TESTING CORRECT OTP ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-user-001' ORDER BY created_at DESC LIMIT 1),
  'test-user-001',
  (SELECT otp_code FROM bookings WHERE profile_customer_id = 'test-user-001' ORDER BY created_at DESC LIMIT 1)
) as result;

-- Check verified
SELECT 
  id,
  otp_code,
  otp_verified,
  otp_verified_at
FROM public.bookings
WHERE profile_customer_id = 'test-user-001'
ORDER BY created_at DESC
LIMIT 1;

-- Cleanup (uncomment to remove test data)
-- DELETE FROM bookings WHERE profile_customer_id = 'test-user-001';

-- ============================================
-- EXPECTED RESULTS:
-- ✅ 3 functions found
-- ✅ 1 trigger found
-- ✅ OTP is 6-digit number (e.g., "123456")
-- ✅ Wrong OTP returns 'wrong_otp', attempts = 1
-- ✅ Correct OTP returns 'success', otp_verified = true
-- ============================================
