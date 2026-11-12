-- ============================================
-- INSTALL OTP TRIGGER - FINAL VERSION
-- ============================================
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- Clean up any existing versions
DROP TRIGGER IF EXISTS bookings_generate_otp ON public.bookings;
DROP TRIGGER IF EXISTS booking_otp_trigger ON public.bookings;
DROP FUNCTION IF EXISTS generate_booking_otp();
DROP FUNCTION IF EXISTS set_booking_otp();
DROP FUNCTION IF EXISTS generate_otp();

-- Create OTP generation function
CREATE OR REPLACE FUNCTION generate_otp()
RETURNS TEXT AS $$
BEGIN
  RETURN LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Create trigger function
CREATE OR REPLACE FUNCTION set_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.otp_code IS NULL OR NEW.otp_code = '' THEN
    NEW.otp_code := generate_otp();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER booking_otp_trigger
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_otp();

-- Verify functions exist
SELECT proname FROM pg_proc WHERE proname IN ('generate_otp','set_booking_otp');

-- Verify trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'booking_otp_trigger';
