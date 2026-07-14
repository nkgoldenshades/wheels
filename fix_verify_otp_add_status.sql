-- ============================================================================
-- FIX: Update verify_otp() to set status = 'completed' when OTP is verified
-- ============================================================================
-- This fixes the issue where bookings show "Expired" badge even after OTP
-- verification because the status wasn't being updated.
-- ============================================================================

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
  v_attempts INT;
BEGIN
  -- Lock the booking row and get current values
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

  -- Validation checks
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

  -- Check if OTP matches
  IF v_booking.otp_code IS DISTINCT FROM p_entered_otp THEN
    -- Increment attempts
    v_attempts := COALESCE(v_booking.otp_attempts, 0) + 1;
    
    UPDATE public.bookings
    SET 
      otp_attempts = v_attempts,
      otp_locked = (v_attempts >= 5)
    WHERE id = p_booking_id;
    
    IF v_attempts >= 5 THEN
      RETURN 'locked';
    END IF;
    
    RETURN 'wrong_otp';
  END IF;

  -- ✅ OTP is correct - mark as verified AND set status to completed
  UPDATE public.bookings
  SET 
    otp_verified = TRUE,
    otp_verified_at = NOW(),
    otp_attempts = NULL,
    otp_locked = FALSE,
    status = 'completed',  -- ← FIX: Added this line!
    updated_at = NOW()     -- ← Also update timestamp
  WHERE id = p_booking_id;

  RETURN 'success';
END;
$$;

-- ============================================================================
-- ALSO FIX: Update any existing bookings that have verified OTP but wrong status
-- ============================================================================
UPDATE public.bookings
SET 
  status = 'completed',
  updated_at = NOW()
WHERE otp_verified = TRUE
  AND status != 'completed'
  AND status NOT IN ('cancelled', 'refunded', 'cancelled_by_customer', 'cancelled_by_provider');

-- ============================================================================
-- Expected status values based on BookingStatus enum:
-- ============================================================================
-- Active statuses:
--   - 'pending'
--   - 'accepted'
--   - 'confirmed'
--   - 'in_progress'
--
-- Terminal statuses:
--   - 'completed'           ← OTP verified bookings should have this
--   - 'rejected'
--   - 'refunded'
--   - 'cancelled'
--   - 'cancelled_by_customer'
--   - 'cancelled_by_provider'
--   - 'no_show'
--   - 'disputed'
--   - 'expired'
-- ============================================================================
