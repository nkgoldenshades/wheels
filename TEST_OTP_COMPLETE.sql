-- ============================================
-- COMPLETE OTP SYSTEM TEST
-- ============================================
-- Run this after installing both:
-- 1. INSTALL_OTP_TRIGGER_FINAL.sql
-- 2. CREATE_OTP_VERIFICATION_FUNCTION.sql
-- ============================================

-- STEP 1: Verify trigger and functions exist
-- ============================================
SELECT '=== CHECKING FUNCTIONS ===' as step;
SELECT proname, prorettype::regtype as return_type
FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp')
ORDER BY proname;

SELECT '=== CHECKING TRIGGER ===' as step;
SELECT tgname, tgenabled, tgrelid::regclass as table_name
FROM pg_trigger 
WHERE tgname = 'booking_otp_trigger';

-- STEP 2: Test OTP auto-generation on INSERT
-- ============================================
SELECT '=== TESTING OTP AUTO-GENERATION ===' as step;

-- Insert a test booking WITHOUT otp_code (should be auto-generated)
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
  otp_code  -- Explicitly set to NULL
) VALUES (
  'test-customer-001',
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
  NULL  -- Backend should generate OTP
) RETURNING 
  id, 
  otp_code, 
  otp_attempts, 
  otp_locked, 
  otp_verified,
  created_at;

-- STEP 3: Verify OTP was generated
-- ============================================
SELECT '=== VERIFYING OTP GENERATION ===' as step;
SELECT 
  id,
  profile_customer_id,
  otp_code,
  LENGTH(otp_code) as otp_length,
  otp_attempts,
  otp_locked,
  otp_verified
FROM public.bookings
WHERE profile_customer_id = 'test-customer-001'
ORDER BY created_at DESC
LIMIT 1;

-- STEP 4: Test OTP verification with WRONG OTP
-- ============================================
SELECT '=== TESTING WRONG OTP (Attempt 1) ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-customer-001' ORDER BY created_at DESC LIMIT 1),
  'test-customer-001',
  '999999'  -- Wrong OTP
) as verification_result;

-- Check attempts incremented
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified
FROM public.bookings
WHERE profile_customer_id = 'test-customer-001'
ORDER BY created_at DESC
LIMIT 1;

-- STEP 5: Test OTP verification with CORRECT OTP
-- ============================================
SELECT '=== TESTING CORRECT OTP ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-customer-001' ORDER BY created_at DESC LIMIT 1),
  'test-customer-001',
  (SELECT otp_code FROM bookings WHERE profile_customer_id = 'test-customer-001' ORDER BY created_at DESC LIMIT 1)
) as verification_result;

-- Check verified
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified,
  otp_verified_at
FROM public.bookings
WHERE profile_customer_id = 'test-customer-001'
ORDER BY created_at DESC
LIMIT 1;

-- STEP 6: Test already verified
-- ============================================
SELECT '=== TESTING ALREADY VERIFIED ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-customer-001' ORDER BY created_at DESC LIMIT 1),
  'test-customer-001',
  (SELECT otp_code FROM bookings WHERE profile_customer_id = 'test-customer-001' ORDER BY created_at DESC LIMIT 1)
) as verification_result;

-- STEP 7: Test locking after 5 failed attempts
-- ============================================
SELECT '=== TESTING LOCK AFTER 5 ATTEMPTS ===' as step;

-- Create another test booking
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
  'test-customer-002',
  'test-provider-002',
  gen_random_uuid(),
  'pending',
  'passenger',
  200.00,
  200.00,
  0.00,
  'INR',
  1,
  'instant',
  'instant',
  NOW(),
  NOW() + INTERVAL '2 hours',
  NULL
) RETURNING id, otp_code;

-- Try wrong OTP 5 times
DO $$
DECLARE
  v_booking_id BIGINT;
  v_result TEXT;
  i INT;
BEGIN
  SELECT id INTO v_booking_id 
  FROM bookings 
  WHERE profile_customer_id = 'test-customer-002' 
  ORDER BY created_at DESC 
  LIMIT 1;

  FOR i IN 1..5 LOOP
    SELECT verify_otp(v_booking_id, 'test-customer-002', '000000') INTO v_result;
    RAISE NOTICE 'Attempt %: %', i, v_result;
  END LOOP;
END $$;

-- Check if locked
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified
FROM public.bookings
WHERE profile_customer_id = 'test-customer-002'
ORDER BY created_at DESC
LIMIT 1;

-- Try correct OTP after lock (should return 'locked')
SELECT '=== TESTING CORRECT OTP AFTER LOCK ===' as step;
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-customer-002' ORDER BY created_at DESC LIMIT 1),
  'test-customer-002',
  (SELECT otp_code FROM bookings WHERE profile_customer_id = 'test-customer-002' ORDER BY created_at DESC LIMIT 1)
) as verification_result;

-- ============================================
-- CLEANUP TEST DATA (uncomment to clean up)
-- ============================================
-- DELETE FROM bookings WHERE profile_customer_id IN ('test-customer-001', 'test-customer-002');

-- ============================================
-- EXPECTED RESULTS SUMMARY
-- ============================================
-- ✅ Functions exist: generate_otp, set_booking_otp, verify_otp
-- ✅ Trigger exists: booking_otp_trigger
-- ✅ OTP auto-generated: 6-digit number (e.g., "123456")
-- ✅ Wrong OTP: returns 'wrong_otp', increments attempts
-- ✅ Correct OTP: returns 'success', sets otp_verified=true
-- ✅ Already verified: returns 'already_verified'
-- ✅ After 5 attempts: otp_locked=true, returns 'locked'
-- ============================================
