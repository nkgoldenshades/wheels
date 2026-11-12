-- ============================================
-- OTP VERIFICATION FUNCTION - CORRECTED
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION verify_otp(BIGINT, TEXT, TEXT) TO anon, authenticated;

-- Verify function exists
SELECT 
  routine_name,
  routine_type,
  security_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'verify_otp';
