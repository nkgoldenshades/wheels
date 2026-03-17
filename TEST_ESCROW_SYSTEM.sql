-- ============================================
-- STRIPE ESCROW SYSTEM TEST SCRIPT
-- ============================================
-- Run these tests to validate all security functions

-- ============================================
-- SETUP: Create test users
-- ============================================

-- Clean up any existing test data
DELETE FROM public.bookings WHERE user_id LIKE 'test_%' OR provider_id LIKE 'test_%';
DELETE FROM public.users WHERE id LIKE 'test_%';

-- Insert test users
INSERT INTO public.users (id, email, profile_name, phone, stripe_account_id, stripe_onboarding_completed)
VALUES 
  ('test_user_customer', 'customer@test.com', 'Test Customer', '+1234567890', NULL, FALSE),
  ('test_user_provider', 'provider@test.com', 'Test Provider', '+0987654321', 'acct_test_provider123', TRUE)
ON CONFLICT (id) DO UPDATE SET
  stripe_account_id = EXCLUDED.stripe_account_id,
  stripe_onboarding_completed = EXCLUDED.stripe_onboarding_completed;

-- ============================================
-- TEST 1: Create Booking Secure
-- ============================================

SELECT '=== TEST 1: Create Booking Secure ===' AS test;

-- Should succeed
SELECT * FROM public.create_booking_secure(
  p_user_id := 'test_user_customer',
  p_provider_id := 'test_user_provider',
  p_post_id := 'test_post_123',
  p_stripe_payment_intent_id := 'pi_test_12345',
  p_amount := 10000,
  p_currency := 'usd',
  p_commission_amount := 1500,
  p_otp := '123456',
  p_countdown_hours := 24
);

-- Verify booking was created
SELECT 
  id,
  user_id,
  provider_id,
  amount,
  commission_amount,
  status,
  countdown_end_time,
  otp_hash IS NOT NULL AS has_otp_hash,
  refund_processing
FROM public.bookings 
WHERE user_id = 'test_user_customer'
ORDER BY created_at DESC 
LIMIT 1;

-- Store booking_id for next tests
DO $$
DECLARE
  v_booking_id TEXT;
BEGIN
  SELECT id INTO v_booking_id
  FROM public.bookings
  WHERE user_id = 'test_user_customer'
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Store in temp table for use in other tests
  CREATE TEMP TABLE IF NOT EXISTS test_context (
    booking_id TEXT,
    otp TEXT DEFAULT '123456'
  );
  
  DELETE FROM test_context;
  INSERT INTO test_context (booking_id) VALUES (v_booking_id);
  
  RAISE NOTICE 'Created booking: %', v_booking_id;
END $$;

-- ============================================
-- TEST 2: Verify OTP Secure (Invalid OTP)
-- ============================================

SELECT '=== TEST 2: Verify OTP Secure (Invalid OTP) ===' AS test;

-- Should fail with "Invalid OTP"
SELECT * FROM public.verify_otp_secure(
  p_booking_id := (SELECT booking_id FROM test_context),
  p_otp := '999999' -- Wrong OTP
);

-- ============================================
-- TEST 3: Verify OTP Secure (Valid OTP)
-- ============================================

SELECT '=== TEST 3: Verify OTP Secure (Valid OTP) ===' AS test;

-- Should succeed
SELECT * FROM public.verify_otp_secure(
  p_booking_id := (SELECT booking_id FROM test_context),
  p_otp := '123456' -- Correct OTP
);

-- Verify booking was marked as OTP verified
SELECT 
  id,
  status,
  otp_verified,
  otp_verified_at
FROM public.bookings 
WHERE id = (SELECT booking_id FROM test_context);

-- ============================================
-- TEST 4: Mark Booking Completed
-- ============================================

SELECT '=== TEST 4: Mark Booking Completed ===' AS test;

-- Should succeed
SELECT public.mark_booking_completed(
  p_booking_id := (SELECT booking_id FROM test_context),
  p_stripe_transfer_id := 'tr_test_12345'
);

-- Verify booking was completed
SELECT 
  id,
  status,
  stripe_transfer_id,
  completed_at
FROM public.bookings 
WHERE id = (SELECT booking_id FROM test_context);

-- ============================================
-- TEST 5: Lock Booking for Refund (Expired)
-- ============================================

SELECT '=== TEST 5: Lock Booking for Refund ===' AS test;

-- Create an expired booking
SELECT * FROM public.create_booking_secure(
  p_user_id := 'test_user_customer',
  p_provider_id := 'test_user_provider',
  p_post_id := 'test_post_expired',
  p_stripe_payment_intent_id := 'pi_test_expired',
  p_amount := 5000,
  p_currency := 'usd',
  p_commission_amount := 750,
  p_otp := '654321',
  p_countdown_hours := 1
);

-- Manually set countdown to past
UPDATE public.bookings
SET countdown_end_time = NOW() - INTERVAL '1 hour'
WHERE stripe_payment_intent_id = 'pi_test_expired';

-- Try to lock for refund (should succeed)
SELECT public.lock_booking_for_refund(
  p_booking_id := (
    SELECT id FROM public.bookings 
    WHERE stripe_payment_intent_id = 'pi_test_expired'
  )
) AS lock_acquired;

-- Verify lock was acquired
SELECT 
  id,
  status,
  refund_processing,
  countdown_end_time < NOW() AS is_expired
FROM public.bookings 
WHERE stripe_payment_intent_id = 'pi_test_expired';

-- Try to lock again (should fail - already locked)
SELECT public.lock_booking_for_refund(
  p_booking_id := (
    SELECT id FROM public.bookings 
    WHERE stripe_payment_intent_id = 'pi_test_expired'
  )
) AS lock_acquired_second_attempt;

-- ============================================
-- TEST 6: Mark Booking Refunded
-- ============================================

SELECT '=== TEST 6: Mark Booking Refunded ===' AS test;

-- Should succeed
SELECT public.mark_booking_refunded(
  p_booking_id := (
    SELECT id FROM public.bookings 
    WHERE stripe_payment_intent_id = 'pi_test_expired'
  ),
  p_stripe_refund_id := 're_test_12345'
);

-- Verify booking was refunded
SELECT 
  id,
  status,
  stripe_refund_id,
  refunded_at,
  refund_processing
FROM public.bookings 
WHERE stripe_payment_intent_id = 'pi_test_expired';

-- ============================================
-- TEST 7: Record Refund Failure
-- ============================================

SELECT '=== TEST 7: Record Refund Failure ===' AS test;

-- Create a booking that will fail refund
SELECT * FROM public.create_booking_secure(
  p_user_id := 'test_user_customer',
  p_provider_id := 'test_user_provider',
  p_post_id := 'test_post_fail',
  p_stripe_payment_intent_id := 'pi_test_fail',
  p_amount := 3000,
  p_currency := 'usd',
  p_commission_amount := 450,
  p_otp := '111111',
  p_countdown_hours := 1
);

-- Record failure
SELECT public.record_refund_failure(
  p_booking_id := (
    SELECT id FROM public.bookings 
    WHERE stripe_payment_intent_id = 'pi_test_fail'
  ),
  p_stripe_payment_intent_id := 'pi_test_fail',
  p_error_message := 'Test error: Stripe API timeout',
  p_current_attempts := 1
);

-- Verify failure was recorded
SELECT 
  booking_id,
  attempts,
  last_error,
  next_attempt_at > NOW() AS has_future_retry,
  resolved
FROM public.refund_failures 
WHERE stripe_payment_intent_id = 'pi_test_fail';

-- Record second failure (should increment attempts)
SELECT public.record_refund_failure(
  p_booking_id := (
    SELECT id FROM public.bookings 
    WHERE stripe_payment_intent_id = 'pi_test_fail'
  ),
  p_stripe_payment_intent_id := 'pi_test_fail',
  p_error_message := 'Test error: Stripe API timeout (retry)',
  p_current_attempts := 2
);

-- Verify attempts incremented
SELECT 
  booking_id,
  attempts,
  last_error,
  next_attempt_at,
  resolved
FROM public.refund_failures 
WHERE stripe_payment_intent_id = 'pi_test_fail';

-- ============================================
-- TEST 8: Get Expired Bookings for Refund
-- ============================================

SELECT '=== TEST 8: Get Expired Bookings for Refund ===' AS test;

-- Create multiple expired bookings
DO $$
BEGIN
  FOR i IN 1..3 LOOP
    PERFORM public.create_booking_secure(
      p_user_id := 'test_user_customer',
      p_provider_id := 'test_user_provider',
      p_post_id := 'test_post_batch_' || i,
      p_stripe_payment_intent_id := 'pi_test_batch_' || i,
      p_amount := 2000 + (i * 100),
      p_currency := 'usd',
      p_commission_amount := 300 + (i * 15),
      p_otp := '000000',
      p_countdown_hours := 1
    );
  END LOOP;
END $$;

-- Set all to expired
UPDATE public.bookings
SET countdown_end_time = NOW() - INTERVAL '1 hour'
WHERE stripe_payment_intent_id LIKE 'pi_test_batch_%';

-- Get expired bookings
SELECT * FROM public.get_expired_bookings_for_refund(10);

-- ============================================
-- TEST 9: Edge Cases
-- ============================================

SELECT '=== TEST 9: Edge Cases ===' AS test;

-- Test 9a: Invalid amount (should fail)
DO $$
BEGIN
  PERFORM public.create_booking_secure(
    p_user_id := 'test_user_customer',
    p_provider_id := 'test_user_provider',
    p_post_id := 'test_post_invalid',
    p_stripe_payment_intent_id := 'pi_test_invalid',
    p_amount := -100, -- Invalid
    p_currency := 'usd',
    p_commission_amount := 15,
    p_otp := '000000',
    p_countdown_hours := 24
  );
  RAISE NOTICE 'ERROR: Should have failed with negative amount';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'PASS: Correctly rejected negative amount';
END $$;

-- Test 9b: Commission > Amount (should fail)
DO $$
BEGIN
  PERFORM public.create_booking_secure(
    p_user_id := 'test_user_customer',
    p_provider_id := 'test_user_provider',
    p_post_id := 'test_post_invalid2',
    p_stripe_payment_intent_id := 'pi_test_invalid2',
    p_amount := 1000,
    p_currency := 'usd',
    p_commission_amount := 1500, -- Invalid
    p_otp := '000000',
    p_countdown_hours := 24
  );
  RAISE NOTICE 'ERROR: Should have failed with commission > amount';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'PASS: Correctly rejected commission > amount';
END $$;

-- Test 9c: Provider without Stripe account (should fail)
INSERT INTO public.users (id, email, profile_name, stripe_account_id)
VALUES ('test_user_no_stripe', 'nostripe@test.com', 'No Stripe User', NULL)
ON CONFLICT (id) DO UPDATE SET stripe_account_id = NULL;

DO $$
BEGIN
  PERFORM public.create_booking_secure(
    p_user_id := 'test_user_customer',
    p_provider_id := 'test_user_no_stripe',
    p_post_id := 'test_post_no_stripe',
    p_stripe_payment_intent_id := 'pi_test_no_stripe',
    p_amount := 1000,
    p_currency := 'usd',
    p_commission_amount := 150,
    p_otp := '000000',
    p_countdown_hours := 24
  );
  RAISE NOTICE 'ERROR: Should have failed with no Stripe account';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'PASS: Correctly rejected provider without Stripe account';
END $$;

-- ============================================
-- TEST SUMMARY
-- ============================================

SELECT '=== TEST SUMMARY ===' AS summary;

SELECT 
  COUNT(*) AS total_test_bookings,
  COUNT(*) FILTER (WHERE status = 'completed') AS completed_bookings,
  COUNT(*) FILTER (WHERE status = 'refunded') AS refunded_bookings,
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_bookings,
  COUNT(*) FILTER (WHERE otp_verified = TRUE) AS otp_verified_bookings
FROM public.bookings
WHERE user_id LIKE 'test_%' OR provider_id LIKE 'test_%';

SELECT 
  COUNT(*) AS total_refund_failures,
  AVG(attempts) AS avg_attempts,
  COUNT(*) FILTER (WHERE resolved = TRUE) AS resolved_failures,
  COUNT(*) FILTER (WHERE resolved = FALSE) AS unresolved_failures
FROM public.refund_failures
WHERE booking_id IN (
  SELECT id FROM public.bookings 
  WHERE user_id LIKE 'test_%' OR provider_id LIKE 'test_%'
);

-- ============================================
-- CLEANUP (Optional)
-- ============================================

-- Uncomment to clean up test data
-- DELETE FROM public.refund_failures WHERE booking_id IN (SELECT id FROM public.bookings WHERE user_id LIKE 'test_%');
-- DELETE FROM public.bookings WHERE user_id LIKE 'test_%' OR provider_id LIKE 'test_%';
-- DELETE FROM public.users WHERE id LIKE 'test_%';
-- DROP TABLE IF EXISTS test_context;

SELECT '=== ALL TESTS COMPLETED ===' AS done;
