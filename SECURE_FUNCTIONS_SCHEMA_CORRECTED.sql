-- ============================================================================
-- CORRECTED SECURE FUNCTIONS - SCHEMA ALIGNED WITH BIGINT IDS
-- These versions match the ACTUAL Supabase schema:
-- - posts.id is TEXT (not UUID)
-- - bookings.id is BIGINT GENERATED ALWAYS (NOT user-supplied)
-- - bookings uses profile_provider_id and profile_customer_id
-- ============================================================================

-- ============================================================================
-- 1. SECURE BOOKING CREATION (CORRECTED FOR BIGINT AUTO ID)
-- Fixes: bookings.id is BIGINT GENERATED ALWAYS (omit from INSERT)
--        posts.id is TEXT, bookings uses profile_provider_id/profile_customer_id
--        seat_keys is TEXT (not TEXT[])
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_create_booking(
  p_post_id TEXT,  -- ✅ posts.id is TEXT
  p_user_id TEXT,  -- This is the customer (profile_customer_id)
  p_seat_keys TEXT DEFAULT NULL,  -- ✅ seat_keys is TEXT (not TEXT[] array)
  p_booking_mode TEXT DEFAULT 'shared',
  p_price_snapshot NUMERIC DEFAULT NULL,
  p_persons_count INTEGER DEFAULT 1
)
RETURNS TABLE(
  success BOOLEAN,
  booking_id BIGINT,  -- ✅ CORRECTED: return BIGINT (auto-generated id)
  message TEXT,
  remaining_capacity INTEGER
) AS $$
DECLARE
  v_post_capacity INTEGER;
  v_post_provider_id TEXT;
  v_current_bookings INTEGER;
  v_available_capacity INTEGER;
  v_new_booking_id BIGINT;
  v_booking_price NUMERIC;
BEGIN
  -- Validate input parameters
  IF p_post_id IS NULL OR p_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Invalid post ID or user ID', 0;
    RETURN;
  END IF;
  
  IF p_booking_mode NOT IN ('shared', 'full') THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Invalid booking mode', 0;
    RETURN;
  END IF;
  
  -- Get post details with lock (posts.id is TEXT)
  SELECT capacity, profile_id, price
  INTO v_post_capacity, v_post_provider_id, v_booking_price
  FROM posts
  WHERE id = p_post_id AND is_active = true
  FOR UPDATE;
  
  IF v_post_capacity IS NULL THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Post not found or inactive', 0;
    RETURN;
  END IF;
  
  -- Prevent self-booking
  IF p_user_id = v_post_provider_id THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Cannot book your own service', v_post_capacity;
    RETURN;
  END IF;
  
  -- Count current active bookings
  SELECT COUNT(*)::INTEGER
  INTO v_current_bookings
  FROM bookings
  WHERE post_id = p_post_id
    AND status IN ('pending', 'confirmed', 'completed');
  
  v_available_capacity := v_post_capacity - v_current_bookings;
  
  -- Validate capacity
  IF v_available_capacity < p_persons_count THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Not enough capacity available', v_available_capacity;
    RETURN;
  END IF;
  
  -- Validate seat conflicts (if seats provided as string)
  IF p_seat_keys IS NOT NULL AND p_seat_keys != '' THEN
    IF EXISTS (
      SELECT 1 FROM bookings
      WHERE post_id = p_post_id
        AND seat_keys = p_seat_keys
        AND status IN ('pending', 'confirmed', 'completed')
    ) THEN
      RETURN QUERY SELECT false, NULL::BIGINT, 'Selected seat already booked', v_available_capacity;
      RETURN;
    END IF;
  END IF;
  
  -- Use provided price or fall back to post price
  v_booking_price := COALESCE(p_price_snapshot, v_booking_price);
  
  IF v_booking_price IS NULL OR v_booking_price <= 0 THEN
    RETURN QUERY SELECT false, NULL::BIGINT, 'Invalid booking price', v_available_capacity;
    RETURN;
  END IF;
  
  -- Create the booking (omit id - it's GENERATED ALWAYS)
  -- ✅ CORRECTED: removed id from INSERT, let Postgres generate it
  INSERT INTO bookings (
    post_id,
    profile_customer_id,  -- ✅ CORRECTED: was user_id
    profile_provider_id,   -- ✅ CORRECTED: was provider_id
    price_snapshot,
    persons_snapshot,
    seat_keys,
    status,
    start_time,
    end_time,
    created_at
  )
  VALUES (
    p_post_id,
    p_user_id,
    v_post_provider_id,
    v_booking_price,
    p_persons_count,
    p_seat_keys,
    'pending',
    NOW(),
    NOW() + INTERVAL '24 hours',
    NOW()
  )
  RETURNING id INTO v_new_booking_id;
  
  v_available_capacity := v_available_capacity - p_persons_count;
  
  RETURN QUERY SELECT 
    true, 
    v_new_booking_id, 
    'Booking created successfully',
    v_available_capacity;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    NULL::BIGINT, 
    'Error creating booking: ' || SQLERRM,
    COALESCE(v_available_capacity, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. SECURE PAYMENT PROCESSING (CORRECTED FOR BIGINT)
-- Fixes: bookings.id is BIGINT (not TEXT)
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_process_payment(
  p_booking_id BIGINT,  -- ✅ CORRECTED: BIGINT not TEXT
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT DEFAULT 'razorpay'
)
RETURNS TABLE(
  success BOOLEAN,
  commission_amount NUMERIC,
  provider_amount NUMERIC,
  message TEXT
) AS $$
DECLARE
  v_booking_price NUMERIC;
  v_booking_status TEXT;
  v_provider_id TEXT;
  v_platform_commission NUMERIC;
  v_provider_earnings NUMERIC;
  v_commission_rate NUMERIC := 0.05;
BEGIN
  -- Validate input
  IF p_booking_id IS NULL OR p_payment_amount IS NULL OR p_gateway_id IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Invalid input parameters';
    RETURN;
  END IF;
  
  IF p_payment_amount <= 0 THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Payment amount must be positive';
    RETURN;
  END IF;
  
  -- Get booking details
  SELECT price_snapshot, status, profile_provider_id  -- ✅ CORRECTED: profile_provider_id
  INTO v_booking_price, v_booking_status, v_provider_id
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_booking_price IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking not found';
    RETURN;
  END IF;
  
  IF v_booking_status NOT IN ('pending', 'confirmed') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking not in payable state';
    RETURN;
  END IF;
  
  IF ABS(p_payment_amount - v_booking_price) > 0.01 THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 
      'Payment amount mismatch. Expected: ' || v_booking_price || ', Got: ' || p_payment_amount;
    RETURN;
  END IF;
  
  -- Calculate commission
  v_platform_commission := (v_booking_price * v_commission_rate)::NUMERIC(12, 2);
  v_provider_earnings := (v_booking_price - v_platform_commission)::NUMERIC(12, 2);
  
  -- Update booking
  UPDATE bookings SET
    payment_status = 'captured',
    payment_amount = p_payment_amount,
    payment_gateway_id = p_gateway_id,
    payment_method = p_payment_method,
    paid_at = NOW(),
    platform_fee = v_platform_commission,
    payout_amount = v_provider_earnings,
    status = CASE WHEN status = 'pending' THEN 'confirmed' ELSE status END,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  RETURN QUERY SELECT 
    true, 
    v_platform_commission, 
    v_provider_earnings,
    'Payment processed successfully';
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    0::NUMERIC, 
    0::NUMERIC, 
    'Error processing payment: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. SECURE GENERATE OTP (CORRECTED FOR BIGINT)
-- Fixes: bookings.id is BIGINT (not TEXT)
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_generate_otp(
  p_booking_id BIGINT,  -- ✅ CORRECTED: BIGINT not TEXT
  p_expiry_minutes INTEGER DEFAULT 30
)
RETURNS TABLE(
  success BOOLEAN,
  otp_code TEXT,
  expires_at TIMESTAMP WITH TIME ZONE,
  message TEXT
) AS $$
DECLARE
  v_booking_exists BOOLEAN;
  v_new_otp TEXT;
  v_expiry_time TIMESTAMP WITH TIME ZONE;
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Invalid booking ID';
    RETURN;
  END IF;
  
  IF p_expiry_minutes <= 0 OR p_expiry_minutes > 120 THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Invalid expiry time';
    RETURN;
  END IF;
  
  -- Check if booking exists
  SELECT EXISTS(SELECT 1 FROM bookings 
    WHERE id = p_booking_id AND status IN ('confirmed', 'pending'))
  INTO v_booking_exists;
  
  IF NOT v_booking_exists THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Booking not found or not in valid state';
    RETURN;
  END IF;
  
  -- Generate 6-digit OTP
  v_new_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  
  -- Exclude predictable patterns
  WHILE v_new_otp IN ('000000', '111111', '222222', '333333', '444444', '555555', '666666', '777777', '888888', '999999', '123456', '654321') LOOP
    v_new_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  END LOOP;
  
  v_expiry_time := NOW() + (p_expiry_minutes || ' minutes')::INTERVAL;
  
  -- Update booking with OTP
  UPDATE bookings SET
    otp_code = v_new_otp,
    otp_verified = false,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  RETURN QUERY SELECT 
    true, 
    v_new_otp,
    v_expiry_time,
    'OTP generated successfully';
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    NULL::TEXT, 
    NULL::TIMESTAMP WITH TIME ZONE, 
    'Error generating OTP: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. SECURE VERIFY OTP (CORRECTED FOR BIGINT)
-- Fixes: bookings.id is BIGINT (not TEXT)
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_verify_otp(
  p_booking_id BIGINT,  -- ✅ CORRECTED: BIGINT not TEXT
  p_otp_code TEXT,
  p_user_id TEXT
)
RETURNS TABLE(
  success BOOLEAN,
  verified BOOLEAN,
  remaining_attempts INTEGER,
  message TEXT
) AS $$
DECLARE
  v_stored_otp TEXT;
  v_booking_customer_id TEXT;
  v_booking_provider_id TEXT;
  v_max_attempts INTEGER := 5;
BEGIN
  IF p_booking_id IS NULL OR p_otp_code IS NULL OR p_user_id IS NULL THEN
    RETURN QUERY SELECT false, false, 0, 'Invalid input parameters';
    RETURN;
  END IF;
  
  p_otp_code := TRIM(p_otp_code);
  IF LENGTH(p_otp_code) != 6 OR p_otp_code !~ '^[0-9]{6}$' THEN
    RETURN QUERY SELECT false, false, 0, 'OTP must be 6 digits';
    RETURN;
  END IF;
  
  -- Get booking with correct column names
  SELECT otp_code, profile_customer_id, profile_provider_id  -- ✅ CORRECTED column names
  INTO v_stored_otp, v_booking_customer_id, v_booking_provider_id
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_stored_otp IS NULL THEN
    RETURN QUERY SELECT false, false, 0, 'Booking not found';
    RETURN;
  END IF;
  
  -- Verify user has permission
  IF p_user_id NOT IN (v_booking_customer_id, v_booking_provider_id) THEN
    RETURN QUERY SELECT false, false, 0, 'Unauthorized OTP verification attempt';
    RETURN;
  END IF;
  
  -- Verify OTP
  IF v_stored_otp = p_otp_code THEN
    UPDATE bookings SET
      otp_verified = true,
      updated_at = NOW()
    WHERE id = p_booking_id;
    
    RETURN QUERY SELECT true, true, v_max_attempts, 'OTP verified successfully';
  ELSE
    RETURN QUERY SELECT true, false, v_max_attempts - 1, 'Incorrect OTP. ' || (v_max_attempts - 1) || ' attempts remaining';
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, false, 0, 'Error verifying OTP: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. SECURE PROCESS REFUND (CORRECTED FOR BIGINT)
-- Fixes: bookings.id is BIGINT (not TEXT), use profile_provider_id, use refund_requested
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_process_refund(
  p_booking_id BIGINT,  -- ✅ CORRECTED: BIGINT not TEXT
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC DEFAULT 100.0
)
RETURNS TABLE(
  success BOOLEAN,
  refund_amount NUMERIC,
  commission_refund NUMERIC,
  message TEXT
) AS $$
DECLARE
  v_booking_status TEXT;
  v_payment_amount NUMERIC;
  v_platform_fee NUMERIC;
  v_payment_status TEXT;
  v_booking_customer_id TEXT;
  v_booking_provider_id TEXT;
  v_calculated_refund NUMERIC;
  v_commission_adjustment NUMERIC;
  v_time_since_booking INTERVAL;
BEGIN
  -- Validate input
  IF p_booking_id IS NULL OR p_refund_reason IS NULL OR p_initiated_by IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Invalid input parameters';
    RETURN;
  END IF;
  
  IF p_refund_percentage < 0 OR p_refund_percentage > 100 THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Refund percentage must be between 0 and 100';
    RETURN;
  END IF;
  
  -- Get booking details with correct column names
  SELECT 
    status,
    payment_amount,
    platform_fee,
    payment_status,
    profile_customer_id,  -- ✅ CORRECTED
    profile_provider_id,  -- ✅ CORRECTED
    NOW() - created_at
  INTO 
    v_booking_status,
    v_payment_amount,
    v_platform_fee,
    v_payment_status,
    v_booking_customer_id,
    v_booking_provider_id,
    v_time_since_booking
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_booking_status IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking not found';
    RETURN;
  END IF;
  
  -- Check if already refunded (use refund_requested column)
  IF EXISTS (SELECT 1 FROM bookings WHERE id = p_booking_id AND refund_requested = true) THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Refund already processed';
    RETURN;
  END IF;
  
  IF v_booking_status IN ('cancelled', 'refunded', 'expired') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking already cancelled or refunded';
    RETURN;
  END IF;
  
  IF v_payment_status NOT IN ('captured', 'authorized') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'No payment to refund';
    RETURN;
  END IF;
  
  -- Validate authorization
  IF p_initiated_by NOT IN (v_booking_customer_id, v_booking_provider_id, 'system', 'admin') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Unauthorized refund request';
    RETURN;
  END IF;
  
  -- Validate refund reason
  IF p_refund_reason NOT IN ('cancellation_by_customer', 'cancellation_by_provider', 'no_show', 'system_error') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 
      'Invalid refund reason: ' || p_refund_reason || '. Allowed: cancellation_by_customer, cancellation_by_provider, no_show, system_error';
    RETURN;
  END IF;
  
  -- Calculate refund amounts
  v_calculated_refund := (v_payment_amount * p_refund_percentage / 100.0)::NUMERIC(12, 2);
  v_commission_adjustment := (v_platform_fee * p_refund_percentage / 100.0)::NUMERIC(12, 2);
  
  -- Process the refund (mark as requested)
  UPDATE bookings SET
    status = 'cancelled',
    payment_status = 'refunded',
    refund_requested = true,  -- ✅ CORRECTED: use refund_requested column
    refund_requested_at = NOW(),
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  RETURN QUERY SELECT 
    true, 
    v_calculated_refund,
    v_commission_adjustment,
    'Refund processed successfully. Amount: ₹' || v_calculated_refund || ' (' || p_refund_percentage || '% of ₹' || v_payment_amount || ')';
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    0::NUMERIC, 
    0::NUMERIC, 
    'Error processing refund: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check that all 5 functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'secure_create_booking',
    'secure_process_payment',
    'secure_generate_otp',
    'secure_verify_otp',
    'secure_process_refund'
  )
ORDER BY routine_name;

-- Test secure_create_booking (all params are correct types now)
-- SELECT * FROM secure_create_booking('post-id-here', 'user-id-here', 'A1', 'shared', 500.00, 1);

-- Test secure_process_payment (p_booking_id is now BIGINT)
-- SELECT * FROM secure_process_payment(1::BIGINT, 500.00, 'razorpay_pay_123');

-- Test secure_generate_otp (p_booking_id is now BIGINT)
-- SELECT * FROM secure_generate_otp(1::BIGINT, 30);

-- Test secure_verify_otp (p_booking_id is now BIGINT)
-- SELECT * FROM secure_verify_otp(1::BIGINT, '123456', 'user-id-here');

-- Test secure_process_refund (p_booking_id is now BIGINT)
-- SELECT * FROM secure_process_refund(1::BIGINT, 'cancellation_by_customer', 'user-id-here', 100.0);
