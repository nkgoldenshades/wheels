-- Create OTP auto-generation trigger for bookings
-- This generates a secure 6-digit OTP when a booking is created

-- Function to generate 6-digit OTP
CREATE OR REPLACE FUNCTION generate_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate 6-digit OTP (100000 to 999999)
  NEW.otp := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
  NEW.otp_attempts := 0;
  NEW.otp_verified := false;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that fires before insert on bookings
DROP TRIGGER IF EXISTS booking_otp_trigger ON public.bookings;
CREATE TRIGGER booking_otp_trigger
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION generate_booking_otp();

-- Verify trigger was created
SELECT tgname, tgtype, tgenabled 
FROM pg_trigger 
WHERE tgname = 'booking_otp_trigger';
