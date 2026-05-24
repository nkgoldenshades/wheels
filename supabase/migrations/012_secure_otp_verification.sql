-- Backend-only OTP verification with attempt lockout.
-- This keeps completion, attempt counting, and audit timestamps on the server.

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS otp_attempts integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS otp_locked boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS otp_verified_at timestamptz;

CREATE OR REPLACE FUNCTION public.verify_otp(
  p_booking_id bigint,
  p_profile_customer_id text,
  p_entered_otp text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking record;
BEGIN
  SELECT
    otp_code,
    COALESCE(otp_attempts, 0) AS otp_attempts,
    COALESCE(otp_locked, false) AS otp_locked,
    COALESCE(otp_verified, false) AS otp_verified,
    profile_customer_id
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;

  IF v_booking.profile_customer_id != p_profile_customer_id THEN
    RETURN 'unauthorized';
  END IF;

  IF v_booking.otp_verified THEN
    RETURN 'already_verified';
  END IF;

  IF v_booking.otp_locked THEN
    RETURN 'locked';
  END IF;

  IF v_booking.otp_code IS DISTINCT FROM p_entered_otp THEN
    UPDATE public.bookings
    SET
      otp_attempts = COALESCE(otp_attempts, 0) + 1,
      otp_locked = (COALESCE(otp_attempts, 0) + 1) >= 5
    WHERE id = p_booking_id;

    RETURN 'wrong_otp';
  END IF;

  UPDATE public.bookings
  SET
    otp_verified = true,
    otp_verified_at = now(),
    otp_attempts = NULL,
    otp_locked = false,
    status = 'completed'
  WHERE id = p_booking_id;

  RETURN 'success';
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_otp(bigint, text, text) TO anon, authenticated;
