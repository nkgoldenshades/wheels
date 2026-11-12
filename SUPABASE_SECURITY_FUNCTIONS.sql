-- ============================================
-- SECURITY DEFINER FUNCTIONS FOR STRIPE ESCROW
-- ============================================
-- These functions run with elevated privileges (service role)
-- and enforce business logic server-side

-- ============================================
-- 1. SECURE BOOKING CREATION
-- ============================================
-- Creates booking with atomic operations and validation
CREATE OR REPLACE FUNCTION public.create_booking_secure(
  p_user_id UUID,
  p_provider_id UUID,
  p_post_id UUID,
  p_stripe_payment_intent_id TEXT,
  p_amount INTEGER,
  p_currency TEXT,
  p_commission_amount INTEGER,
  p_otp TEXT,
  p_countdown_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  booking_id UUID,
  countdown_end_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking_id UUID;
  v_countdown_end TIMESTAMPTZ;
  v_created_at TIMESTAMPTZ;
BEGIN
  -- Validate inputs
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  
  IF p_commission_amount < 0 OR p_commission_amount >= p_amount THEN
    RAISE EXCEPTION 'Invalid commission amount';
  END IF;
  
  IF p_countdown_hours <= 0 OR p_countdown_hours > 168 THEN
    RAISE EXCEPTION 'Countdown hours must be between 1 and 168 (7 days)';
  END IF;
  
  -- Check provider exists and has Stripe account
  IF NOT EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = p_provider_id 
    AND stripe_account_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Provider does not have a valid Stripe account';
  END IF;
  
  -- Calculate countdown end time
  v_countdown_end := NOW() + (p_countdown_hours || ' hours')::INTERVAL;
  
  -- Insert booking atomically
  INSERT INTO public.bookings (
    user_id,
    provider_id,
    post_id,
    stripe_payment_intent_id,
    amount,
    currency,
    commission_amount,
    otp,
    countdown_end_time,
    status,
    refund_processing,
    created_at
  ) VALUES (
    p_user_id,
    p_provider_id,
    p_post_id,
    p_stripe_payment_intent_id,
    p_amount,
    p_currency,
    p_commission_amount,
    p_otp,
    v_countdown_end,
    'pending',
    FALSE,
    NOW()
  )
  RETURNING id, countdown_end_time, created_at
  INTO v_booking_id, v_countdown_end, v_created_at;
  
  -- Return result
  RETURN QUERY SELECT v_booking_id, v_countdown_end, v_created_at;
END;
$$;

-- Grant execute to service role only
REVOKE ALL ON FUNCTION public.create_booking_secure FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_booking_secure TO service_role;

COMMENT ON FUNCTION public.create_booking_secure IS 
  'Securely creates a booking with validation. Only callable by service role (backend).';

-- ============================================
-- 2. SECURE OTP VERIFICATION
-- ============================================
-- Verifies OTP and marks booking as ready for fund release
CREATE OR REPLACE FUNCTION public.verify_otp_secure(
  p_booking_id UUID,
  p_otp TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  provider_stripe_account_id TEXT,
  transfer_amount INTEGER,
  currency TEXT,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_provider_account TEXT;
  v_transfer_amount INTEGER;
BEGIN
  -- Get booking with lock
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  -- Check booking exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, 0, NULL::TEXT, 'Booking not found';
    RETURN;
  END IF;
  
  -- Check status
  IF v_booking.status != 'pending' THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, 0, NULL::TEXT, 
      'Booking already processed (status: ' || v_booking.status || ')';
    RETURN;
  END IF;
  
  -- Check if expired
  IF NOW() > v_booking.countdown_end_time THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, 0, NULL::TEXT, 'Booking expired';
    RETURN;
  END IF;
  
  -- Verify OTP
  IF v_booking.otp != p_otp THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, 0, NULL::TEXT, 'Invalid OTP';
    RETURN;
  END IF;
  
  -- Get provider's Stripe account
  SELECT stripe_account_id INTO v_provider_account
  FROM public.users
  WHERE id = v_booking.provider_id;
  
  IF v_provider_account IS NULL THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, 0, NULL::TEXT, 
      'Provider has not set up payout account';
    RETURN;
  END IF;
  
  -- Calculate transfer amount
  v_transfer_amount := v_booking.amount - v_booking.commission_amount;
  
  -- Mark OTP as verified (don't complete yet - wait for Stripe transfer)
  UPDATE public.bookings
  SET otp_verified = TRUE,
      otp_verified_at = NOW()
  WHERE id = p_booking_id;
  
  -- Return success with transfer details
  RETURN QUERY SELECT 
    TRUE,
    v_provider_account,
    v_transfer_amount,
    v_booking.currency,
    'OTP verified - ready for fund transfer'::TEXT;
END;
$$;

-- Grant execute to service role only
REVOKE ALL ON FUNCTION public.verify_otp_secure FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_otp_secure TO service_role;

COMMENT ON FUNCTION public.verify_otp_secure IS 
  'Verifies OTP and returns transfer details. Only callable by service role (backend).';

-- ============================================
-- 3. MARK BOOKING COMPLETED
-- ============================================
-- Called after successful Stripe transfer
CREATE OR REPLACE FUNCTION public.mark_booking_completed(
  p_booking_id UUID,
  p_stripe_transfer_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.bookings
  SET status = 'completed',
      stripe_transfer_id = p_stripe_transfer_id,
      completed_at = NOW()
  WHERE id = p_booking_id
    AND status = 'pending'
    AND otp_verified = TRUE;
  
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_booking_completed FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_booking_completed TO service_role;

-- ============================================
-- 4. ATOMIC REFUND LOCK
-- ============================================
-- Atomically locks a booking for refund processing
CREATE OR REPLACE FUNCTION public.lock_booking_for_refund(
  p_booking_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locked BOOLEAN;
BEGIN
  -- Try to acquire lock atomically
  UPDATE public.bookings
  SET refund_processing = TRUE
  WHERE id = p_booking_id
    AND status = 'pending'
    AND refund_processing = FALSE
    AND countdown_end_time < NOW();
  
  v_locked := FOUND;
  RETURN v_locked;
END;
$$;

REVOKE ALL ON FUNCTION public.lock_booking_for_refund FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lock_booking_for_refund TO service_role;

-- ============================================
-- 5. MARK BOOKING REFUNDED
-- ============================================
-- Called after successful Stripe refund
CREATE OR REPLACE FUNCTION public.mark_booking_refunded(
  p_booking_id UUID,
  p_stripe_refund_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.bookings
  SET status = 'refunded',
      stripe_refund_id = p_stripe_refund_id,
      refunded_at = NOW(),
      refund_processing = FALSE
  WHERE id = p_booking_id;
  
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_booking_refunded FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_booking_refunded TO service_role;

-- ============================================
-- 6. MARK REFUND FAILED
-- ============================================
-- Called when refund fails
CREATE OR REPLACE FUNCTION public.mark_refund_failed(
  p_booking_id UUID,
  p_error_message TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.bookings
  SET status = 'refund_failed',
      refund_error = p_error_message,
      refund_failed_at = NOW(),
      refund_processing = FALSE
  WHERE id = p_booking_id;
  
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_refund_failed FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_refund_failed TO service_role;

-- ============================================
-- 7. GET EXPIRED BOOKINGS FOR REFUND
-- ============================================
-- Returns bookings that need auto-refund
CREATE OR REPLACE FUNCTION public.get_expired_bookings_for_refund(
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
  booking_id UUID,
  stripe_payment_intent_id TEXT,
  amount INTEGER,
  user_id UUID,
  provider_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    id,
    bookings.stripe_payment_intent_id,
    bookings.amount,
    bookings.user_id,
    bookings.provider_id
  FROM public.bookings
  WHERE status = 'pending'
    AND countdown_end_time < NOW()
    AND refund_processing = FALSE
    AND stripe_payment_intent_id IS NOT NULL
  ORDER BY countdown_end_time ASC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.get_expired_bookings_for_refund FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_expired_bookings_for_refund TO service_role;

-- ============================================
-- ADD MISSING COLUMN
-- ============================================
-- Add otp_verified column if it doesn't exist
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS otp_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bookings_otp_verified
  ON public.bookings(otp_verified)
  WHERE otp_verified = TRUE;
