-- ============================================
-- OTP VERIFICATION FUNCTION
-- ============================================
-- This function verifies OTP for bookings with:
-- - Attempt tracking (max 5 attempts)
-- - Auto-locking after 5 failed attempts
-- - Security checks (ownership, already verified, locked)
-- ============================================

CREATE OR REPLACE FUNCTION verify_otp(
  p_booking_id BIGINT,
  p_profile_customer_id TEXT,
  p_entered_otp TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  -- Lock the booking row for update
  SELECT 
    otp_code, 
    otp_attempts, 
    otp_locked, 
    otp_verified, 
    profile_customer_id
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  -- Check if booking exists
  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;

  -- Check if user owns this booking
  IF v_booking.profile_customer_id != p_profile_customer_id THEN
    RETURN 'unauthorized';
  END IF;

  -- Check if already verified
  IF v_booking.otp_verified THEN
    RETURN 'already_verified';
  END IF;

  -- Check if locked due to too many attempts
  IF v_booking.otp_locked THEN
    RETURN 'locked';
  END IF;

  -- Check if OTP is wrong
  IF v_booking.otp_code IS DISTINCT FROM p_entered_otp THEN
    -- Increment attempts and lock if >= 5
    UPDATE public.bookings
    SET 
      otp_attempts = otp_attempts + 1,
      otp_locked = ((otp_attempts + 1) >= 5)
    WHERE id = p_booking_id;

    RETURN 'wrong_otp';
  END IF;

  -- OTP is correct - mark as verified
  UPDATE public.bookings
  SET 
    otp_verified = TRUE,
    otp_verified_at = NOW()
  WHERE id = p_booking_id;

  RETURN 'success';
END;
$$;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
-- Allow anon and authenticated users to call this function
GRANT EXECUTE ON FUNCTION verify_otp(BIGINT, TEXT, TEXT) TO anon, authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
-- Check if function exists
SELECT 
  routine_name,
  routine_type,
  security_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'verify_otp';

-- ============================================
-- TEST CASES
-- ============================================

-- Test 1: Create a test booking with OTP
INSERT INTO public.bookings (
  post_id,
  profile_customer_id,
  profile_provider_id,
  price_snapshot,
  start_time,
  end_time,
  otp_code,
  service_type,
  total_price
) VALUES (
  gen_random_uuid(),
  'test-otp-user-123',
  'test-provider-456',
  100.0,
  now(),
  now() + interval '1 hour',
  '123456',
  'passenger',
  100.0
) RETURNING id, otp_code, otp_attempts, otp_locked, otp_verified;

-- Test 2: Try wrong OTP (should increment attempts)
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-otp-user-123' ORDER BY created_at DESC LIMIT 1),
  'test-otp-user-123',
  '999999'
) as result;

-- Check attempts increased
SELECT id, otp_code, otp_attempts, otp_locked, otp_verified
FROM bookings
WHERE profile_customer_id = 'test-otp-user-123'
ORDER BY created_at DESC
LIMIT 1;

-- Test 3: Try correct OTP (should verify)
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-otp-user-123' ORDER BY created_at DESC LIMIT 1),
  'test-otp-user-123',
  '123456'
) as result;

-- Check verified
SELECT id, otp_code, otp_attempts, otp_locked, otp_verified, otp_verified_at
FROM bookings
WHERE profile_customer_id = 'test-otp-user-123'
ORDER BY created_at DESC
LIMIT 1;

-- Test 4: Try verifying again (should return 'already_verified')
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-otp-user-123' ORDER BY created_at DESC LIMIT 1),
  'test-otp-user-123',
  '123456'
) as result;

-- ============================================
-- CLEANUP TEST DATA
-- ============================================
-- DELETE FROM bookings WHERE profile_customer_id = 'test-otp-user-123';

-- ============================================
-- RETURN VALUES
-- ============================================
-- 'success'           - OTP verified successfully
-- 'not_found'         - Booking ID doesn't exist
-- 'unauthorized'      - User doesn't own this booking
-- 'already_verified'  - OTP already verified
-- 'locked'            - Too many failed attempts (5+)
-- 'wrong_otp'         - Incorrect OTP (attempts incremented)
-- ============================================
