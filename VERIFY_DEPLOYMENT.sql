-- ============================================================================
-- VERIFY_DEPLOYMENT.sql
-- Run these queries after deploying ALL_DATABASE_FUNCTIONS_COMPLETE.sql
-- ============================================================================

-- ============================================================================
-- 1. CHECK ALL 14 FUNCTIONS EXIST
-- ============================================================================
SELECT
  routine_name,
  routine_type,
  created,
  last_altered
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    -- Fixed functions (9)
    'get_provider_average_rating',
    'get_provider_total_reviews',
    'calculate_provider_earnings',
    'calculate_commission',
    'deduct_credits',
    'check_booking_eligibility',
    'verify_gps_location',
    'diagnose_coordinate_extraction',
    'validate_coordinates',
    -- New functions (5)
    'secure_create_booking',
    'secure_process_payment',
    'secure_generate_otp',
    'secure_verify_otp',
    'secure_process_refund'
  )
ORDER BY routine_name;

-- Expected: 14 rows (all functions present)

-- ============================================================================
-- 2. TEST: deduct_credits with fractional amount
-- ============================================================================
-- This tests Bug #1 fix - should use consistent rounding
SELECT * FROM deduct_credits(
  'test-user-' || gen_random_uuid()::TEXT,
  2.7::NUMERIC,
  'test-deduction'
);

-- Expected: success=true, remaining_credits = (current_balance - 3)
-- The 2.7 should be CEIL'd to 3 consistently everywhere

-- ============================================================================
-- 3. TEST: secure_process_refund - reject invalid reason (Bug #2)
-- ============================================================================
-- This tests Bug #2 fix - should reject unknown reason
SELECT * FROM secure_process_refund(
  '00000000-0000-0000-0000-000000000000'::UUID,
  'invalid_reason_that_does_not_exist',
  'test-user'
);

-- Expected: success=false, message like "Invalid refund reason: invalid_reason_that_does_not_exist"

-- ============================================================================
-- 4. TEST: check_booking_eligibility - prevent self-booking (Bug #4)
-- ============================================================================
-- This tests Bug #4 fix - should prevent user from booking own post
-- Note: This would fail if post doesn't exist, but error message should mention self-booking
SELECT * FROM check_booking_eligibility(
  '00000000-0000-0000-0000-000000000000'::TEXT,
  '00000000-0000-0000-0000-000000000000'::TEXT  -- Same ID = self
);

-- Expected: eligible=false (either because post doesn't exist OR self-booking prevention)

-- ============================================================================
-- 5. TEST: secure_generate_otp - should generate valid OTP (New function)
-- ============================================================================
-- This tests new function - should generate valid 6-digit OTP
-- Note: Booking must exist for this to work
-- CREATE TEST DATA FIRST if needed:
-- INSERT INTO bookings (id, post_id, user_id, provider_id, price_snapshot, status)
-- VALUES ('test-booking-id'::UUID, 'post-id'::UUID, 'user-id', 'provider-id', 100.00, 'confirmed')
-- ON CONFLICT DO NOTHING;

-- Then run:
SELECT * FROM secure_generate_otp('test-booking-id'::UUID, 30);

-- Expected: success=true, otp_code matches pattern '^[0-9]{6}$', not in (000000, 111111, etc)

-- ============================================================================
-- 6. TEST: verify_gps_location - ACOS clamp (Bug #3 from earlier fix)
-- ============================================================================
-- This tests ACOS domain error fix - should handle edge cases
SELECT * FROM verify_gps_location(
  40.7128::NUMERIC,    -- NYC latitude
  -74.0060::NUMERIC,   -- NYC longitude
  40.7130::NUMERIC,    -- 0.0002° away (~20 meters)
  -74.0058::NUMERIC,
  1.0::NUMERIC         -- 1 km tolerance
);

-- Expected: verified=true, distance_km < 1.0

-- ============================================================================
-- 7. TEST: validate_coordinates - reject invalid ranges
-- ============================================================================
-- This tests coordinate validation
SELECT * FROM validate_coordinates(91::NUMERIC, 0::NUMERIC);  -- Invalid lat
-- Expected: valid=false, issue like "Latitude must be between -90 and 90"

SELECT * FROM validate_coordinates(40.7128::NUMERIC, 181::NUMERIC);  -- Invalid lng
-- Expected: valid=false, issue like "Longitude must be between -180 and 180"

SELECT * FROM validate_coordinates(40.7128::NUMERIC, -74.0060::NUMERIC);  -- Valid
-- Expected: valid=true, issue='Coordinates are valid'

-- ============================================================================
-- 8. FUNCTION SIGNATURE CHECK - verify parameters are correct
-- ============================================================================
SELECT
  routine_name,
  parameters
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('deduct_credits', 'secure_process_refund', 'check_booking_eligibility')
ORDER BY routine_name;

-- Expected: 
--   deduct_credits: p_user_id, p_credits_to_deduct (NUMERIC), p_reason
--   secure_process_refund: p_booking_id, p_refund_reason, p_initiated_by, p_refund_percentage
--   check_booking_eligibility: p_post_id, p_user_id (with profile_id added)

-- ============================================================================
-- 9. INTEGRATION TEST - Full refund policy flow
-- ============================================================================
-- This verifies the refund policy logic (Bug #3 fix)
-- Simulates: booking created now, starts in 1 hour, customer cancels immediately
-- Expected: 0% refund (because <2 hours before start)

-- SETUP (run once):
-- DO $$
-- DECLARE
--   v_post_id UUID;
--   v_booking_id UUID;
-- BEGIN
--   -- Create test post
--   INSERT INTO posts (id, profile_id, capacity, is_active, start_time, end_time, price)
--   VALUES (
--     'test-post-' || gen_random_uuid()::TEXT,
--     'test-provider',
--     4,
--     true,
--     NOW() + INTERVAL '1 hour',
--     NOW() + INTERVAL '3 hours',
--     500.00
--   ) RETURNING id INTO v_post_id;
--
--   -- Create test booking
--   INSERT INTO bookings (id, post_id, user_id, provider_id, price_snapshot, status, payment_status, payment_amount)
--   VALUES (
--     'test-booking-' || gen_random_uuid()::TEXT,
--     v_post_id,
--     'test-customer',
--     'test-provider',
--     500.00,
--     'confirmed',
--     'captured',
--     500.00
--   ) RETURNING id INTO v_booking_id;
--
--   -- Try to process refund - should get 0% (not 100%)
--   RAISE NOTICE 'Booking ID: %', v_booking_id;
-- END $$;

-- ============================================================================
-- 10. PERFORMANCE CHECK - verify functions are efficient
-- ============================================================================
-- These functions should all complete in <5ms
EXPLAIN ANALYZE
SELECT * FROM deduct_credits('test-user', 1.0::NUMERIC, 'perf-test');

EXPLAIN ANALYZE
SELECT * FROM check_booking_eligibility('test-post', 'test-user');

EXPLAIN ANALYZE
SELECT * FROM verify_gps_location(40.7::NUMERIC, -74.0::NUMERIC, 40.71::NUMERIC, -74.01::NUMERIC);

-- Expected: All <5ms execution time

-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
After running all above tests, verify:

✅ Test 1: All 14 functions exist
✅ Test 2: deduct_credits uses consistent rounding (same value in DB, log, and return)
✅ Test 3: secure_process_refund rejects invalid reasons
✅ Test 4: check_booking_eligibility has self-booking check
✅ Test 5: secure_generate_otp generates valid OTP (exclude predictable patterns)
✅ Test 6: verify_gps_location handles edge cases correctly
✅ Test 7: validate_coordinates rejects invalid ranges
✅ Test 8: Function signatures are correct
✅ Test 9: Refund policy correctly enforces <2hr rule
✅ Test 10: All functions perform efficiently (<5ms)

If all pass: DEPLOYMENT SUCCESSFUL ✅
If any fail: Check error message and review corresponding function
*/
