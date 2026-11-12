-- ============================================
-- FIXED OTP VERIFICATION FUNCTION
-- ============================================
-- This fixes the delimiter issue and adds search_path security
-- ============================================

CREATE OR REPLACE FUNCTION verify_otp(
  p_booking_id BIGINT,
  p_profile_customer_id TEXT,
  p_entered_otp TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- Security: Prevent search_path attacks
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
      otp_attempts = COALESCE(otp_attempts, 0) + 1,  -- Handle NULL case
      otp_locked = (COALESCE(otp_attempts, 0) + 1) >= 5
    WHERE id = p_booking_id;

    RETURN 'wrong_otp';
  END IF;

  -- OTP is correct - mark as verified and reset attempts to NULL
  UPDATE public.bookings
  SET 
    otp_verified = TRUE,
    otp_verified_at = NOW(),
    otp_attempts = NULL  -- Reset to NULL to save storage
  WHERE id = p_booking_id;

  RETURN 'success';
END;
$$;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION verify_otp(BIGINT, TEXT, TEXT) TO anon, authenticated;

-- ============================================
-- VERIFY INSTALLATION
-- ============================================
SELECT 
  routine_name,
  routine_type,
  security_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'verify_otp';

-- Expected output:
-- routine_name | routine_type | security_type | return_type
-- verify_otp   | FUNCTION     | DEFINER       | text

-- ============================================
-- QUICK TEST
-- ============================================
-- 1. Create test booking
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
  'test-fix-user',
  'test-fix-provider',
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
  NULL
) RETURNING id, otp_code, otp_attempts, otp_locked;

-- 2. Test wrong OTP
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-fix-user' ORDER BY created_at DESC LIMIT 1),
  'test-fix-user',
  '999999'
) as result;

-- 3. Check if attempts incremented
SELECT 
  id,
  otp_code,
  otp_attempts,  -- Should be 1
  otp_locked,    -- Should be false
  otp_verified   -- Should be false
FROM bookings
WHERE profile_customer_id = 'test-fix-user'
ORDER BY created_at DESC
LIMIT 1;

-- 4. Cleanup
-- DELETE FROM bookings WHERE profile_customer_id = 'test-fix-user';

-- ============================================
-- CHANGES FROM PREVIOUS VERSION
-- ============================================
-- 1. Fixed delimiter: $ → $$
-- 2. Added SET search_path = public for security
-- 3. Added COALESCE to handle NULL otp_attempts
-- 4. Reset otp_attempts to NULL after successful verification
-- ============================================
