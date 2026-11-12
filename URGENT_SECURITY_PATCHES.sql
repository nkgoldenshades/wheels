-- ============================================
-- URGENT SECURITY PATCHES
-- ============================================
-- Run these immediately to fix critical security issues

-- ============================================
-- 1. ENABLE PGCRYPTO FOR OTP HASHING
-- ============================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================
-- 2. MIGRATE OTP TO HASHED STORAGE
-- ============================================

-- Add otp_hash column
ALTER TABLE public.bookings 
  ADD COLUMN IF NOT EXISTS otp_hash TEXT;

-- Migrate existing OTPs to hashed format
UPDATE public.bookings 
SET otp_hash = encode(digest(otp, 'sha256'), 'hex') 
WHERE otp IS NOT NULL AND otp_hash IS NULL;

-- Drop plain text OTP column (CRITICAL SECURITY FIX)
-- WARNING: This will delete plain text OTPs
-- Make sure you've migrated all data first
ALTER TABLE public.bookings 
  DROP COLUMN IF EXISTS otp;

-- Add index for faster OTP lookups
CREATE INDEX IF NOT EXISTS idx_bookings_otp_hash 
  ON public.bookings(otp_hash) 
  WHERE otp_hash IS NOT NULL;

-- ============================================
-- 3. CREATE REFUND FAILURES TABLE (DEAD LETTER QUEUE)
-- ============================================

CREATE TABLE IF NOT EXISTS public.refund_failures (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id TEXT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  stripe_payment_intent_id TEXT NOT NULL,
  attempts INTEGER DEFAULT 1,
  last_error TEXT NOT NULL,
  next_attempt_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ
);

-- Indexes for refund failure tracking
CREATE INDEX IF NOT EXISTS idx_refund_failures_booking_id 
  ON public.refund_failures(booking_id);

CREATE INDEX IF NOT EXISTS idx_refund_failures_next_attempt 
  ON public.refund_failures(next_attempt_at) 
  WHERE resolved = FALSE;

CREATE INDEX IF NOT EXISTS idx_refund_failures_resolved 
  ON public.refund_failures(resolved);

-- ============================================
-- 4. UPDATE SECURITY FUNCTIONS WITH OTP HASHING
-- ============================================

-- Updated create_booking_secure with OTP hashing
CREATE OR REPLACE FUNCTION public.create_booking_secure(
  p_user_id TEXT,
  p_provider_id TEXT,
  p_post_id TEXT,
  p_stripe_payment_intent_id TEXT,
  p_amount INTEGER,
  p_currency TEXT,
  p_commission_amount INTEGER,
  p_otp TEXT, -- Plain text OTP (will be hashed)
  p_countdown_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
  booking_id TEXT,
  countdown_end_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking_id TEXT;
  v_countdown_end TIMESTAMPTZ;
  v_created_at TIMESTAMPTZ;
  v_otp_hash TEXT;
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
  
  -- Hash OTP (SECURITY: Never store plain text)
  v_otp_hash := encode(digest(p_otp, 'sha256'), 'hex');
  
  -- Calculate countdown end time
  v_countdown_end := NOW() + (p_countdown_hours || ' hours')::INTERVAL;
  
  -- Generate booking ID
  v_booking_id := 'booking_' || gen_random_uuid()::TEXT;
  
  -- Insert booking atomically
  INSERT INTO public.bookings (
    id,
    user_id,
    provider_id,
    post_id,
    stripe_payment_intent_id,
    amount,
    currency,
    commission_amount,
    otp_hash,
    countdown_end_time,
    status,
    refund_processing,
    created_at
  ) VALUES (
    v_booking_id,
    p_user_id,
    p_provider_id,
    p_post_id,
    p_stripe_payment_intent_id,
    p_amount,
    p_currency,
    p_commission_amount,
    v_otp_hash,
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

-- Updated verify_otp_secure with OTP hashing
CREATE OR REPLACE FUNCTION public.verify_otp_secure(
  p_booking_id TEXT,
  p_otp TEXT -- Plain text OTP (will be hashed for comparison)
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
  v_otp_hash TEXT;
BEGIN
  -- Hash the provided OTP
  v_otp_hash := encode(digest(p_otp, 'sha256'), 'hex');
  
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
  
  -- Verify OTP hash
  IF v_booking.otp_hash != v_otp_hash THEN
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
  
  -- Mark OTP as verified
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

-- ============================================
-- 5. ADD REFUND FAILURE TRACKING FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION public.record_refund_failure(
  p_booking_id TEXT,
  p_stripe_payment_intent_id TEXT,
  p_error_message TEXT,
  p_current_attempts INTEGER DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_failure_id UUID;
  v_next_attempt TIMESTAMPTZ;
BEGIN
  -- Calculate next attempt with exponential backoff
  -- 2^attempts minutes (1min, 2min, 4min, 8min, 16min, etc.)
  v_next_attempt := NOW() + (POWER(2, p_current_attempts) || ' minutes')::INTERVAL;
  
  -- Insert or update failure record
  INSERT INTO public.refund_failures (
    booking_id,
    stripe_payment_intent_id,
    attempts,
    last_error,
    next_attempt_at
  ) VALUES (
    p_booking_id,
    p_stripe_payment_intent_id,
    p_current_attempts,
    p_error_message,
    v_next_attempt
  )
  ON CONFLICT (booking_id) 
  DO UPDATE SET
    attempts = p_current_attempts,
    last_error = p_error_message,
    next_attempt_at = v_next_attempt,
    updated_at = NOW()
  RETURNING id INTO v_failure_id;
  
  RETURN v_failure_id;
END;
$$;

-- Add unique constraint for booking_id in refund_failures
ALTER TABLE public.refund_failures
  ADD CONSTRAINT refund_failures_booking_id_unique 
  UNIQUE (booking_id);

-- ============================================
-- 6. GRANT PERMISSIONS
-- ============================================

REVOKE ALL ON FUNCTION public.create_booking_secure FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_booking_secure TO service_role;

REVOKE ALL ON FUNCTION public.verify_otp_secure FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_otp_secure TO service_role;

REVOKE ALL ON FUNCTION public.record_refund_failure FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_refund_failure TO service_role;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check pgcrypto is enabled
SELECT * FROM pg_extension WHERE extname = 'pgcrypto';

-- Check otp_hash column exists and otp is dropped
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bookings' 
AND column_name IN ('otp', 'otp_hash');

-- Check refund_failures table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'refund_failures';

-- Check functions are updated
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('create_booking_secure', 'verify_otp_secure', 'record_refund_failure');
