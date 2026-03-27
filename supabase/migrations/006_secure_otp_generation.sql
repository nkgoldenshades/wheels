-- Migration: Secure OTP Generation in Database
-- This ensures OTPs are generated server-side for security

-- Function to generate a secure 6-digit OTP
CREATE OR REPLACE FUNCTION generate_otp()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
  -- Generate a random 6-digit number (100000 to 999999)
  RETURN LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
END;
$;

-- Function to automatically generate OTP when a booking is created
CREATE OR REPLACE FUNCTION set_booking_otp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
  -- Only generate OTP if not provided or empty
  IF NEW.otp IS NULL OR NEW.otp = '' THEN
    NEW.otp := generate_otp();
  END IF;
  RETURN NEW;
END;
$;

-- Create trigger to auto-generate OTP on booking insert
DROP TRIGGER IF EXISTS trigger_set_booking_otp ON bookings;
CREATE TRIGGER trigger_set_booking_otp
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_otp();

-- Also regenerate OTP when booking status changes to 'accepted' (for re-booking scenarios)
CREATE OR REPLACE FUNCTION regenerate_otp_on_accept()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
  -- If status changed from pending to accepted, generate new OTP
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    NEW.otp := generate_otp();
    NEW.otp_verified := FALSE;
  END IF;
  RETURN NEW;
END;
$;

DROP TRIGGER IF EXISTS trigger_regenerate_otp_on_accept ON bookings;
CREATE TRIGGER trigger_regenerate_otp_on_accept
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION regenerate_otp_on_accept();

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION generate_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION set_booking_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION regenerate_otp_on_accept() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION generate_otp() IS 'Generates a secure random 6-digit OTP for bookings';
COMMENT ON FUNCTION set_booking_otp() IS 'Trigger function to auto-generate OTP when booking is created';
COMMENT ON FUNCTION regenerate_otp_on_accept() IS 'Trigger function to regenerate OTP when booking status changes to accepted';

-- Add OTP attempt tracking for fraud prevention
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS otp_attempts INTEGER DEFAULT 0;

-- Function to verify OTP with fraud detection (max 4 attempts)
CREATE OR REPLACE FUNCTION verify_otp_with_fraud_check(
  p_booking_id TEXT,
  p_otp TEXT
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  attempts_remaining INTEGER,
  booking_closed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
  v_booking RECORD;
  v_max_attempts INTEGER := 4;
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Booking not found', 0, FALSE;
    RETURN;
  END IF;

  -- Check if booking is already closed/cancelled
  IF v_booking.status IN ('cancelled', 'fraud_suspected', 'refunded', 'completed') THEN
    RETURN QUERY SELECT FALSE, 'Booking is closed', 0, TRUE;
    RETURN;
  END IF;

  -- Check if OTP matches
  IF v_booking.otp = p_otp THEN
    -- Success - reset attempts and mark verified
    UPDATE bookings
    SET otp_attempts = 0, otp_verified = TRUE
    WHERE id = p_booking_id;
    
    RETURN QUERY SELECT TRUE, 'OTP verified successfully', v_max_attempts, FALSE;
    RETURN;
  END IF;

  -- Wrong OTP - increment attempts
  UPDATE bookings
  SET otp_attempts = otp_attempts + 1
  WHERE id = p_booking_id;

  -- Check if max attempts reached - close booking as fraud
  IF v_booking.otp_attempts + 1 >= v_max_attempts THEN
    UPDATE bookings
    SET status = 'fraud_suspected'
    WHERE id = p_booking_id;
    
    RETURN QUERY SELECT 
      FALSE, 
      'Too many failed attempts. Booking closed due to suspicious activity', 
      0,
      TRUE;
  ELSE
    RETURN QUERY SELECT 
      FALSE, 
      'Invalid OTP', 
      v_max_attempts - (v_booking.otp_attempts + 1),
      FALSE;
  END IF;
END;
$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION verify_otp_with_fraud_check(TEXT, TEXT) TO authenticated;

-- Add comment
COMMENT ON FUNCTION verify_otp_with_fraud_check(TEXT, TEXT) IS 'Verifies OTP with fraud detection - closes booking after 4 failed attempts';

-- Reset attempts when new OTP is generated
CREATE OR REPLACE FUNCTION reset_otp_attempts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
  -- Reset attempts when OTP changes
  IF OLD.otp IS DISTINCT FROM NEW.otp THEN
    NEW.otp_attempts := 0;
  END IF;
  RETURN NEW;
END;
$;

DROP TRIGGER IF EXISTS trigger_reset_otp_attempts ON bookings;
CREATE TRIGGER trigger_reset_otp_attempts
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.otp IS DISTINCT FROM NEW.otp)
  EXECUTE FUNCTION reset_otp_attempts();

GRANT EXECUTE ON FUNCTION reset_otp_attempts() TO authenticated;

COMMENT ON FUNCTION reset_otp_attempts() IS 'Resets OTP attempt counter when a new OTP is generated';
