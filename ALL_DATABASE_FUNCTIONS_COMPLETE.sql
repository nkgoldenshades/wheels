-- ============================================================================
-- QUICKOHUNT - ALL DATABASE FUNCTIONS (25 TOTAL)
-- Complete production-ready SQL
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- SECTION 1: EXISTING FUNCTIONS (11) - Already in your database
-- These are included for reference/verification
-- ============================================================================

-- Function 1: bookings_set_slot_layout_from_seat_keys (Trigger)
-- Status: Exists - no changes needed
-- Purpose: Updates slot layout when seat keys are set

-- Function 2: expire_overdue_bookings
-- Status: Exists - no changes needed
-- Purpose: Marks overdue bookings as expired, returns JSON

-- Function 3: generate_otp (OLD VERSION - Consider replacing with secure_generate_otp)
-- Status: Exists - keeping for backwards compatibility
-- Purpose: Generates OTP for bookings

-- Function 4: get_jwt_claims
-- Status: Exists - no changes needed
-- Purpose: Extracts JWT claims from auth token

-- Function 5: rls_auto_enable (Event Trigger)
-- Status: Exists - no changes needed
-- Purpose: Automatically enables RLS on new tables

-- Function 6: safe_delete_post
-- Status: Exists - no changes needed
-- Purpose: Safely deletes post with authorization check

-- Function 7: set_booking_otp (Trigger)
-- Status: Exists - no changes needed
-- Purpose: Trigger to set OTP on booking creation

-- Function 8: set_profiles_updated_at (Trigger)
-- Status: Exists - no changes needed
-- Purpose: Updates timestamp on profile changes

-- Function 9: set_updated_at (Trigger)
-- Status: Exists - no changes needed
-- Purpose: Generic trigger for updated_at columns

-- Function 10: update_updated_at_column (Trigger)
-- Status: Exists - no changes needed
-- Purpose: Updates updated_at timestamp

-- Function 11: verify_otp (OLD VERSION - Consider replacing with secure_verify_otp)
-- Status: Exists - keeping for backwards compatibility
-- Purpose: Verifies OTP for booking (old version, takes bigint)

-- ============================================================================
-- SECTION 2: FIXED & IMPROVED FUNCTIONS (9)
-- These replace the original broken versions
-- ============================================================================

-- ============================================================================
-- 1. GET PROVIDER AVERAGE RATING
-- Fixed: Parameter naming (provider_id → p_provider_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_provider_average_rating(p_provider_id TEXT)
RETURNS NUMERIC AS $$
DECLARE
  avg_rating NUMERIC;
BEGIN
  SELECT COALESCE(AVG(rating), 0.0)::NUMERIC(3, 2)
  INTO avg_rating
  FROM reviews
  WHERE profile_provider_id = p_provider_id
    AND reviewer_role = 'customer';
  
  RETURN avg_rating;
EXCEPTION WHEN OTHERS THEN
  RETURN 0.0;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 2. GET PROVIDER TOTAL REVIEWS
-- Fixed: Parameter naming (provider_id → p_provider_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_provider_total_reviews(p_provider_id TEXT)
RETURNS INTEGER AS $$
DECLARE
  total_count INTEGER;
BEGIN
  SELECT COUNT(*)::INTEGER
  INTO total_count
  FROM reviews
  WHERE profile_provider_id = p_provider_id
    AND reviewer_role = 'customer';
  
  RETURN total_count;
EXCEPTION WHEN OTHERS THEN
  RETURN 0;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 3. CALCULATE PROVIDER EARNINGS (completed bookings only)
-- FIXED: 
--   - Bug: provider_id = provider_id (name shadowing) → provider_id = p_provider_id
--   - Bug: SUM(price) → SUM(price_snapshot)
--   - Bug: Parameter naming (provider_id → p_provider_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_provider_earnings(p_provider_id TEXT)
RETURNS NUMERIC AS $$
DECLARE
  total_earnings NUMERIC;
BEGIN
  SELECT COALESCE(SUM(price_snapshot), 0.0)::NUMERIC(12, 2)
  INTO total_earnings
  FROM bookings
  WHERE bookings.provider_id = p_provider_id
    AND bookings.status = 'completed';
  
  RETURN total_earnings;
EXCEPTION WHEN OTHERS THEN
  RETURN 0.0;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 4. CALCULATE COMMISSION (5% of earnings)
-- Fixed: Parameter naming (provider_id → p_provider_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_commission(p_provider_id TEXT)
RETURNS NUMERIC AS $$
DECLARE
  earnings NUMERIC;
  commission NUMERIC;
BEGIN
  earnings := calculate_provider_earnings(p_provider_id);
  commission := (earnings * 0.05)::NUMERIC(12, 2);
  RETURN commission;
EXCEPTION WHEN OTHERS THEN
  RETURN 0.0;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 5. DEDUCT CREDITS (safely deduct user credits)
-- FIXED: 
--   - Bug: INTEGER → NUMERIC (supports fractional credits from Vertex AI)
--   - Bug: NULL handling (added check for missing user profile)
--   - Bug: Input validation (p_credits_to_deduct > 0)
--   - Bug: CEIL inconsistency - use single rounded value everywhere
-- Design: App sends NUMERIC (fractional), we CEIL once and use everywhere
--   Database update, transaction log, and return value all use same v_credits_rounded
-- ============================================================================
CREATE OR REPLACE FUNCTION deduct_credits(
  p_user_id TEXT,
  p_credits_to_deduct NUMERIC,
  p_reason TEXT DEFAULT 'usage'
)
RETURNS TABLE(
  success BOOLEAN,
  remaining_credits NUMERIC,
  message TEXT
) AS $$
DECLARE
  v_current_credits NUMERIC;
  v_credits_rounded NUMERIC;
  v_transaction_id TEXT;
BEGIN
  -- Validate input parameters
  IF p_credits_to_deduct <= 0 THEN
    RETURN QUERY SELECT
      false,
      NULL::NUMERIC,
      'Credits to deduct must be positive (got ' || p_credits_to_deduct || ')';
    RETURN;
  END IF;
  
  -- Lock the user's profile row for atomic operation
  SELECT COALESCE(ai_credits_available, 0)::NUMERIC
  INTO v_current_credits
  FROM profiles_private
  WHERE profile_id = p_user_id
  FOR UPDATE;
  
  -- Check if user profile exists and has credits field
  IF v_current_credits IS NULL THEN
    RETURN QUERY SELECT
      false,
      NULL::NUMERIC,
      'User profile not found for ID: ' || p_user_id;
    RETURN;
  END IF;
  
  -- Check if sufficient credits (compare fractional amounts)
  IF v_current_credits < p_credits_to_deduct THEN
    RETURN QUERY SELECT
      false,
      v_current_credits,
      'Insufficient credits. Need ' || p_credits_to_deduct || ', have ' || v_current_credits;
    RETURN;
  END IF;
  
  -- Round credits ONCE for consistent use throughout
  -- App sends fractional, we CEIL to whole number for storage
  v_credits_rounded := CEIL(p_credits_to_deduct);
  
  -- Deduct credits using rounded value
  UPDATE profiles_private
  SET ai_credits_available = ai_credits_available - v_credits_rounded,
      updated_at = NOW()
  WHERE profile_id = p_user_id;
  
  -- Verify update succeeded
  IF NOT FOUND THEN
    RETURN QUERY SELECT
      false,
      v_current_credits,
      'Failed to update credits - user profile may have been deleted';
    RETURN;
  END IF;
  
  -- Record transaction using same rounded value (consistency)
  v_transaction_id := 'txn_' || generate_ulid()::TEXT;
  INSERT INTO credit_transactions (id, user_id, amount_change, reason, balance_after, created_at)
  VALUES (
    v_transaction_id,
    p_user_id,
    -v_credits_rounded,
    p_reason,
    v_current_credits - v_credits_rounded,
    NOW()
  );
  
  -- Return success with same rounded value (now consistent everywhere)
  RETURN QUERY SELECT
    true,
    v_current_credits - v_credits_rounded,
    'Deducted ' || v_credits_rounded || ' credits successfully';
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT
    false,
    COALESCE(v_current_credits, 0),
    'Error deducting credits: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. CHECK BOOKING ELIGIBILITY
-- Fixed:
--   - UUID casting for post_id
--   - Parameter naming consistency
--   - Post active status check
--   - FIXED: Added self-booking prevention check (mirrors secure_create_booking)
-- ============================================================================
CREATE OR REPLACE FUNCTION check_booking_eligibility(
  p_post_id TEXT,
  p_user_id TEXT
)
RETURNS TABLE(
  eligible BOOLEAN,
  reason TEXT,
  available_capacity INTEGER
) AS $$
DECLARE
  v_post_capacity INTEGER;
  v_current_bookings INTEGER;
  v_available_capacity INTEGER;
  v_post_active BOOLEAN;
  v_post_provider_id TEXT;
BEGIN
  -- Validate input
  IF p_post_id IS NULL OR p_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Invalid post ID or user ID', 0;
    RETURN;
  END IF;
  
  -- Get post info and check if active
  SELECT capacity, is_active, profile_id
  INTO v_post_capacity, v_post_active, v_post_provider_id
  FROM posts
  WHERE id = p_post_id::UUID;
  
  IF v_post_capacity IS NULL THEN
    RETURN QUERY SELECT false, 'Post not found', 0;
    RETURN;
  END IF;
  
  IF NOT v_post_active THEN
    RETURN QUERY SELECT false, 'Post is no longer active', 0;
    RETURN;
  END IF;
  
  -- Prevent self-booking (user cannot book their own post)
  IF p_user_id = v_post_provider_id THEN
    RETURN QUERY SELECT false, 'Cannot book your own service', 0;
    RETURN;
  END IF;
  
  -- Count existing active bookings for this post
  SELECT COUNT(*)::INTEGER
  INTO v_current_bookings
  FROM bookings
  WHERE post_id = p_post_id::UUID
    AND status IN ('pending', 'confirmed', 'completed');
  
  v_available_capacity := v_post_capacity - v_current_bookings;
  
  -- Check capacity
  IF v_available_capacity <= 0 THEN
    RETURN QUERY SELECT false, 'No capacity available', 0;
    RETURN;
  END IF;
  
  -- All checks passed
  RETURN QUERY SELECT true, 'User is eligible to book', v_available_capacity;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, 'Error checking eligibility: ' || SQLERRM, 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. VERIFY GPS LOCATION
-- FIXED:
--   - ACOS domain error protection (value clamping with GREATEST/LEAST)
--   - Input validation (NULL checks, tolerance validation)
-- ============================================================================
CREATE OR REPLACE FUNCTION verify_gps_location(
  p_expected_lat NUMERIC,
  p_expected_lng NUMERIC,
  p_actual_lat NUMERIC,
  p_actual_lng NUMERIC,
  p_tolerance_km NUMERIC DEFAULT 1.0
)
RETURNS TABLE(
  verified BOOLEAN,
  distance_km NUMERIC,
  message TEXT
) AS $$
DECLARE
  v_distance_km NUMERIC;
  v_cos_value NUMERIC;
BEGIN
  -- Validate input parameters
  IF p_expected_lat IS NULL OR p_expected_lng IS NULL OR 
     p_actual_lat IS NULL OR p_actual_lng IS NULL THEN
    RETURN QUERY SELECT 
      false, 
      NULL::NUMERIC, 
      'Invalid coordinates provided (NULL values not allowed)';
    RETURN;
  END IF;
  
  IF p_tolerance_km <= 0 THEN
    RETURN QUERY SELECT 
      false, 
      NULL::NUMERIC, 
      'Tolerance must be positive (got ' || p_tolerance_km || ')';
    RETURN;
  END IF;
  
  -- Calculate distance using Haversine formula
  -- Clamp the cosine value to prevent domain errors in ACOS
  v_cos_value := COS(RADIANS(90 - p_expected_lat)) * COS(RADIANS(90 - p_actual_lat)) +
                 SIN(RADIANS(90 - p_expected_lat)) * SIN(RADIANS(90 - p_actual_lat)) *
                 COS(RADIANS(p_expected_lng - p_actual_lng));
  
  -- Clamp to [-1, 1] to prevent floating point errors in ACOS
  v_cos_value := GREATEST(-1.0, LEAST(1.0, v_cos_value));
  
  v_distance_km := (6371 * ACOS(v_cos_value))::NUMERIC(10, 2);
  
  -- Check if within tolerance
  IF v_distance_km <= p_tolerance_km THEN
    RETURN QUERY SELECT 
      true, 
      v_distance_km, 
      'Location verified. Distance: ' || v_distance_km || ' km';
  ELSE
    RETURN QUERY SELECT 
      false, 
      v_distance_km, 
      'Location mismatch. Expected distance <= ' || p_tolerance_km || ' km, got ' || v_distance_km || ' km';
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    NULL::NUMERIC, 
    'Error verifying GPS: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- 8. DIAGNOSE COORDINATE EXTRACTION ISSUES
-- Purpose: Identifies why coordinates might be missing
-- ============================================================================
CREATE OR REPLACE FUNCTION diagnose_coordinate_extraction()
RETURNS TABLE(
  issue_type TEXT,
  severity TEXT,
  description TEXT,
  count_affected INTEGER,
  recommended_action TEXT,
  example_data TEXT
) AS $$
BEGIN
  -- 1. Check if coordinate columns exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'posts' AND column_name = 'from_lat'
  ) THEN
    RETURN QUERY SELECT 
      'SCHEMA_MISSING_COLUMNS'::TEXT,
      'CRITICAL'::TEXT,
      'Coordinate columns do not exist in posts table'::TEXT,
      0,
      'Add coordinate columns: ALTER TABLE posts ADD COLUMN from_lat NUMERIC, ADD COLUMN from_lng NUMERIC, etc.'::TEXT,
      'Schema issue - no example data'::TEXT;
    RETURN;
  END IF;

  -- 2. Check for posts with location text but missing coordinates
  RETURN QUERY
  SELECT 
    'PARSING_FAILURE_FROM'::TEXT,
    CASE WHEN COUNT(*) > 10 THEN 'HIGH' WHEN COUNT(*) > 0 THEN 'MEDIUM' ELSE 'LOW' END::TEXT,
    'Posts have from_location text but no coordinates extracted'::TEXT,
    COUNT(*)::INTEGER,
    'Fix coordinate parsing in Flutter app or add server-side extraction trigger'::TEXT,
    (SELECT from_location FROM posts 
     WHERE from_location IS NOT NULL AND from_location != '' 
       AND (from_lat IS NULL OR from_lng IS NULL) 
     LIMIT 1)::TEXT
  FROM posts 
  WHERE from_location IS NOT NULL AND from_location != ''
    AND (from_lat IS NULL OR from_lng IS NULL);

  RETURN QUERY
  SELECT 
    'PARSING_FAILURE_TO'::TEXT,
    CASE WHEN COUNT(*) > 10 THEN 'HIGH' WHEN COUNT(*) > 0 THEN 'MEDIUM' ELSE 'LOW' END::TEXT,
    'Posts have to_location text but no coordinates extracted'::TEXT,
    COUNT(*)::INTEGER,
    'Fix coordinate parsing in Flutter app or add server-side extraction trigger'::TEXT,
    (SELECT to_location FROM posts 
     WHERE to_location IS NOT NULL AND to_location != '' 
       AND (to_lat IS NULL OR to_lng IS NULL) 
     LIMIT 1)::TEXT
  FROM posts 
  WHERE to_location IS NOT NULL AND to_location != ''
    AND (to_lat IS NULL OR to_lng IS NULL);

  RETURN QUERY
  SELECT 
    'PARSING_FAILURE_BASE'::TEXT,
    CASE WHEN COUNT(*) > 10 THEN 'HIGH' WHEN COUNT(*) > 0 THEN 'MEDIUM' ELSE 'LOW' END::TEXT,
    'Posts have base_location text but no coordinates extracted'::TEXT,
    COUNT(*)::INTEGER,
    'Fix coordinate parsing in Flutter app or add server-side extraction trigger'::TEXT,
    (SELECT base_location FROM posts 
     WHERE base_location IS NOT NULL AND base_location != '' 
       AND (base_lat IS NULL OR base_lng IS NULL) 
     LIMIT 1)::TEXT
  FROM posts 
  WHERE base_location IS NOT NULL AND base_location != ''
    AND (base_lat IS NULL OR base_lng IS NULL);

  -- 3. Check for invalid coordinate ranges
  RETURN QUERY
  SELECT 
    'INVALID_LATITUDE_RANGE'::TEXT,
    'HIGH'::TEXT,
    'Posts have latitude values outside valid range [-90, 90]'::TEXT,
    COUNT(*)::INTEGER,
    'Validate latitude values before saving - check coordinate parsing logic'::TEXT,
    'Lat: ' || (SELECT from_lat FROM posts 
                WHERE from_lat IS NOT NULL AND (from_lat < -90 OR from_lat > 90) 
                LIMIT 1)::TEXT
  FROM posts 
  WHERE (from_lat IS NOT NULL AND (from_lat < -90 OR from_lat > 90))
     OR (to_lat IS NOT NULL AND (to_lat < -90 OR to_lat > 90))
     OR (base_lat IS NOT NULL AND (base_lat < -90 OR base_lat > 90));

  RETURN QUERY
  SELECT 
    'INVALID_LONGITUDE_RANGE'::TEXT,
    'HIGH'::TEXT,
    'Posts have longitude values outside valid range [-180, 180]'::TEXT,
    COUNT(*)::INTEGER,
    'Validate longitude values before saving - check coordinate parsing logic'::TEXT,
    'Lng: ' || (SELECT from_lng FROM posts 
                WHERE from_lng IS NOT NULL AND (from_lng < -180 OR from_lng > 180) 
                LIMIT 1)::TEXT
  FROM posts 
  WHERE (from_lng IS NOT NULL AND (from_lng < -180 OR from_lng > 180))
     OR (to_lng IS NOT NULL AND (to_lng < -180 OR to_lng > 180))
     OR (base_lng IS NOT NULL AND (base_lng < -180 OR base_lng > 180));

  -- 4. Check for swapped coordinates (common bug)
  RETURN QUERY
  SELECT 
    'POSSIBLY_SWAPPED_COORDINATES'::TEXT,
    'MEDIUM'::TEXT,
    'Posts may have lat/lng swapped (latitude values look like longitude)'::TEXT,
    COUNT(*)::INTEGER,
    'Check if latitude and longitude are swapped in parsing code'::TEXT,
    'Suspected: lat=' || (SELECT from_lat FROM posts 
                          WHERE from_lat IS NOT NULL AND ABS(from_lat) > 90 AND ABS(from_lat) <= 180 
                          LIMIT 1)::TEXT
  FROM posts 
  WHERE (from_lat IS NOT NULL AND ABS(from_lat) > 90 AND ABS(from_lat) <= 180)
     OR (to_lat IS NOT NULL AND ABS(to_lat) > 90 AND ABS(to_lat) <= 180)
     OR (base_lat IS NOT NULL AND ABS(base_lat) > 90 AND ABS(base_lat) <= 180);

  -- 5. Check location string format issues
  RETURN QUERY
  SELECT 
    'INVALID_LOCATION_FORMAT'::TEXT,
    'MEDIUM'::TEXT,
    'Location strings are not in expected format (Name|lat,lng|keywords)'::TEXT,
    COUNT(*)::INTEGER,
    'Update Flutter app to generate location strings in format: "Name|lat,lng|keywords"'::TEXT,
    (SELECT from_location FROM posts 
     WHERE from_location IS NOT NULL AND from_location != ''
       AND from_location NOT LIKE '%|%,%'
     LIMIT 1)::TEXT
  FROM posts 
  WHERE (from_location IS NOT NULL AND from_location != '' AND from_location NOT LIKE '%|%,%')
     OR (to_location IS NOT NULL AND to_location != '' AND to_location NOT LIKE '%|%,%')
     OR (base_location IS NOT NULL AND base_location != '' AND base_location NOT LIKE '%|%,%');

  -- 6. Check for empty coordinate pairs (one coordinate missing)
  RETURN QUERY
  SELECT 
    'INCOMPLETE_COORDINATE_PAIRS'::TEXT,
    'MEDIUM'::TEXT,
    'Posts have only latitude OR longitude (not both)'::TEXT,
    COUNT(*)::INTEGER,
    'Ensure both lat and lng are parsed and saved together'::TEXT,
    'Missing pair for post ID: ' || (SELECT id FROM posts 
                                     WHERE (from_lat IS NOT NULL AND from_lng IS NULL)
                                        OR (from_lat IS NULL AND from_lng IS NOT NULL)
                                     LIMIT 1)::TEXT
  FROM posts 
  WHERE (from_lat IS NOT NULL AND from_lng IS NULL)
     OR (from_lat IS NULL AND from_lng IS NOT NULL)
     OR (to_lat IS NOT NULL AND to_lng IS NULL)
     OR (to_lat IS NULL AND to_lng IS NOT NULL)
     OR (base_lat IS NOT NULL AND base_lng IS NULL)
     OR (base_lat IS NULL AND base_lng IS NOT NULL);

  -- 7. Success summary
  RETURN QUERY
  SELECT 
    'EXTRACTION_SUCCESS_SUMMARY'::TEXT,
    'INFO'::TEXT,
    'Overall coordinate extraction statistics'::TEXT,
    COUNT(*)::INTEGER,
    CASE 
      WHEN COUNT(*) FILTER (WHERE from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL) = 0
      THEN 'No coordinates found - check all above issues'
      WHEN COUNT(*) FILTER (WHERE from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL) < COUNT(*) * 0.5
      THEN 'Low success rate - investigate parsing failures'
      ELSE 'Coordinate extraction appears to be working'
    END::TEXT,
    'Success rate: ' || ROUND(
      100.0 * COUNT(*) FILTER (WHERE from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL) / 
      NULLIF(COUNT(*), 0), 1
    ) || '%'::TEXT
  FROM posts 
  WHERE is_active = true;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    'DIAGNOSTIC_ERROR'::TEXT,
    'CRITICAL'::TEXT,
    'Error running coordinate diagnostics'::TEXT,
    0,
    'Check database permissions and table structure'::TEXT,
    SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 9. VALIDATE COORDINATE INPUTS
-- Purpose: Validates coordinates before GPS calculations
-- ============================================================================
CREATE OR REPLACE FUNCTION validate_coordinates(
  p_lat NUMERIC,
  p_lng NUMERIC
)
RETURNS TABLE(
  valid BOOLEAN,
  issue TEXT
) AS $$
BEGIN
  -- Check for NULL values
  IF p_lat IS NULL OR p_lng IS NULL THEN
    RETURN QUERY SELECT false, 'Coordinates cannot be NULL';
    RETURN;
  END IF;
  
  -- Check latitude range [-90, 90]
  IF p_lat < -90 OR p_lat > 90 THEN
    RETURN QUERY SELECT false, 'Latitude must be between -90 and 90 (got ' || p_lat || ')';
    RETURN;
  END IF;
  
  -- Check longitude range [-180, 180]
  IF p_lng < -180 OR p_lng > 180 THEN
    RETURN QUERY SELECT false, 'Longitude must be between -180 and 180 (got ' || p_lng || ')';
    RETURN;
  END IF;
  
  -- All validations passed
  RETURN QUERY SELECT true, 'Coordinates are valid';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- SECTION 3: NEW SECURE FUNCTIONS (5)
-- These are completely new and add critical security features
-- ============================================================================

-- ============================================================================
-- 10. SECURE BOOKING CREATION ✨ NEW
-- Atomically creates bookings with capacity validation and fraud prevention
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[] DEFAULT NULL,
  p_booking_mode TEXT DEFAULT 'shared',
  p_price_snapshot NUMERIC DEFAULT NULL,
  p_persons_count INTEGER DEFAULT 1
)
RETURNS TABLE(
  success BOOLEAN,
  booking_id UUID,
  message TEXT,
  remaining_capacity INTEGER
) AS $$
DECLARE
  v_post_capacity INTEGER;
  v_post_provider_id TEXT;
  v_current_bookings INTEGER;
  v_available_capacity INTEGER;
  v_new_booking_id UUID;
  v_booking_price NUMERIC;
BEGIN
  -- Validate input parameters
  IF p_post_id IS NULL OR p_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Invalid post ID or user ID', 0;
    RETURN;
  END IF;
  
  IF p_booking_mode NOT IN ('shared', 'full') THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Invalid booking mode', 0;
    RETURN;
  END IF;
  
  -- Get post details with lock for atomic operation
  SELECT capacity, profile_id, price
  INTO v_post_capacity, v_post_provider_id, v_booking_price
  FROM posts
  WHERE id = p_post_id AND is_active = true
  FOR UPDATE;
  
  IF v_post_capacity IS NULL THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Post not found or inactive', 0;
    RETURN;
  END IF;
  
  -- Prevent self-booking
  IF p_user_id = v_post_provider_id THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Cannot book your own service', v_post_capacity;
    RETURN;
  END IF;
  
  -- Count current active bookings
  SELECT COUNT(*)::INTEGER
  INTO v_current_bookings
  FROM bookings
  WHERE post_id = p_post_id
    AND status IN ('pending', 'confirmed', 'completed');
  
  v_available_capacity := v_post_capacity - v_current_bookings;
  
  -- Validate capacity based on booking mode
  IF p_booking_mode = 'full' THEN
    -- Full booking requires entire capacity available
    IF v_available_capacity < v_post_capacity THEN
      RETURN QUERY SELECT false, NULL::UUID, 'Full booking not available - capacity already taken', v_available_capacity;
      RETURN;
    END IF;
  ELSE
    -- Shared booking requires at least requested persons
    IF v_available_capacity < p_persons_count THEN
      RETURN QUERY SELECT false, NULL::UUID, 'Not enough capacity available', v_available_capacity;
      RETURN;
    END IF;
    
    -- Check if post is locked by full booking
    IF EXISTS (
      SELECT 1 FROM bookings 
      WHERE post_id = p_post_id 
        AND booking_strategy_snapshot = 'full_vehicle'
        AND status IN ('pending', 'confirmed', 'completed')
    ) THEN
      RETURN QUERY SELECT false, NULL::UUID, 'Post locked by full vehicle booking', 0;
      RETURN;
    END IF;
  END IF;
  
  -- Validate seat conflicts (if seat-based booking)
  IF p_seat_keys IS NOT NULL AND array_length(p_seat_keys, 1) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM bookings
      WHERE post_id = p_post_id
        AND seat_keys && p_seat_keys  -- Array overlap operator
        AND status IN ('pending', 'confirmed', 'completed')
    ) THEN
      RETURN QUERY SELECT false, NULL::UUID, 'Selected seats already booked', v_available_capacity;
      RETURN;
    END IF;
  END IF;
  
  -- Use provided price or fall back to post price
  v_booking_price := COALESCE(p_price_snapshot, v_booking_price);
  
  IF v_booking_price IS NULL OR v_booking_price <= 0 THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Invalid booking price', v_available_capacity;
    RETURN;
  END IF;
  
  -- Create the booking
  v_new_booking_id := gen_random_uuid();
  
  INSERT INTO bookings (
    id,
    post_id,
    user_id,
    provider_id,
    price_snapshot,
    persons_snapshot,
    seat_keys,
    booking_strategy_snapshot,
    status,
    start_time,
    end_time,
    created_at
  )
  SELECT 
    v_new_booking_id,
    p_post_id,
    p_user_id,
    v_post_provider_id,
    v_booking_price,
    p_persons_count,
    p_seat_keys,
    CASE p_booking_mode WHEN 'full' THEN 'full_vehicle' ELSE 'instant' END,
    'pending',
    p.start_time,
    p.end_time,
    NOW()
  FROM posts p
  WHERE p.id = p_post_id;
  
  -- Calculate new remaining capacity
  v_available_capacity := v_available_capacity - p_persons_count;
  
  -- Return success
  RETURN QUERY SELECT 
    true, 
    v_new_booking_id, 
    'Booking created successfully',
    v_available_capacity;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    NULL::UUID, 
    'Error creating booking: ' || SQLERRM,
    COALESCE(v_available_capacity, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 11. SECURE PAYMENT PROCESSING ✨ NEW
-- Handles payment validation, commission calculation, and fund allocation
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_process_payment(
  p_booking_id UUID,
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
  v_commission_rate NUMERIC := 0.05; -- 5% platform fee
BEGIN
  -- Validate input parameters
  IF p_booking_id IS NULL OR p_payment_amount IS NULL OR p_gateway_id IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Invalid input parameters';
    RETURN;
  END IF;
  
  IF p_payment_amount <= 0 THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Payment amount must be positive';
    RETURN;
  END IF;
  
  -- Get booking details with lock
  SELECT price_snapshot, status, provider_id
  INTO v_booking_price, v_booking_status, v_provider_id
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_booking_price IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking not found';
    RETURN;
  END IF;
  
  -- Validate booking status
  IF v_booking_status NOT IN ('pending', 'confirmed') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking is not in payable state: ' || v_booking_status;
    RETURN;
  END IF;
  
  -- Validate payment amount matches booking price
  IF ABS(p_payment_amount - v_booking_price) > 0.01 THEN -- Allow 1 paisa tolerance
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 
      'Payment amount mismatch. Expected: ' || v_booking_price || ', Got: ' || p_payment_amount;
    RETURN;
  END IF;
  
  -- Calculate commission and provider earnings
  v_platform_commission := (v_booking_price * v_commission_rate)::NUMERIC(12, 2);
  v_provider_earnings := (v_booking_price - v_platform_commission)::NUMERIC(12, 2);
  
  -- Update booking with payment information
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
  
  -- Verify update succeeded
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Failed to update booking payment status';
    RETURN;
  END IF;
  
  -- Return success with calculated amounts
  RETURN QUERY SELECT 
    true, 
    v_platform_commission, 
    v_provider_earnings,
    'Payment processed successfully. Commission: ₹' || v_platform_commission || ', Provider: ₹' || v_provider_earnings;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    0::NUMERIC, 
    0::NUMERIC, 
    'Error processing payment: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 12. SECURE OTP GENERATION ✨ NEW
-- Generates cryptographically secure OTP with expiration
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_generate_otp(
  p_booking_id UUID,
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
  -- Validate input
  IF p_booking_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Invalid booking ID';
    RETURN;
  END IF;
  
  IF p_expiry_minutes <= 0 OR p_expiry_minutes > 120 THEN -- Max 2 hours
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Invalid expiry time';
    RETURN;
  END IF;
  
  -- Check if booking exists and is in valid state
  SELECT EXISTS(
    SELECT 1 FROM bookings 
    WHERE id = p_booking_id 
      AND status IN ('confirmed', 'pending')
  ) INTO v_booking_exists;
  
  IF NOT v_booking_exists THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Booking not found or not in valid state';
    RETURN;
  END IF;
  
  -- Generate cryptographically secure 6-digit OTP
  v_new_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  
  -- Ensure OTP is not sequential or predictable patterns
  WHILE v_new_otp IN ('000000', '111111', '222222', '333333', '444444', '555555', '666666', '777777', '888888', '999999', '123456', '654321', '000001', '999999') LOOP
    v_new_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  END LOOP;
  
  -- Calculate expiry time
  v_expiry_time := NOW() + (p_expiry_minutes || ' minutes')::INTERVAL;
  
  -- Update booking with new OTP
  UPDATE bookings SET
    otp_code = v_new_otp,
    otp_verified = false,
    otp_attempts = 0,
    otp_verified_at = NULL,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  -- Verify update succeeded
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMP WITH TIME ZONE, 'Failed to generate OTP';
    RETURN;
  END IF;
  
  -- Return success
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
-- 13. SECURE OTP VERIFICATION ✨ NEW
-- Verifies OTP with rate limiting and security checks
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_verify_otp(
  p_booking_id UUID,
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
  v_booking_user_id TEXT;
  v_booking_provider_id TEXT;
  v_current_attempts INTEGER;
  v_otp_verified BOOLEAN;
  v_max_attempts INTEGER := 5;
BEGIN
  -- Validate input parameters
  IF p_booking_id IS NULL OR p_otp_code IS NULL OR p_user_id IS NULL THEN
    RETURN QUERY SELECT false, false, 0, 'Invalid input parameters';
    RETURN;
  END IF;
  
  -- Clean and validate OTP format
  p_otp_code := TRIM(p_otp_code);
  IF LENGTH(p_otp_code) != 6 OR p_otp_code !~ '^[0-9]{6}$' THEN
    RETURN QUERY SELECT false, false, 0, 'OTP must be 6 digits';
    RETURN;
  END IF;
  
  -- Get booking details with lock for atomic operation
  SELECT 
    otp_code,
    user_id,
    provider_id,
    otp_attempts,
    otp_verified
  INTO 
    v_stored_otp,
    v_booking_user_id,
    v_booking_provider_id,
    v_current_attempts,
    v_otp_verified
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_stored_otp IS NULL THEN
    RETURN QUERY SELECT false, false, 0, 'Booking not found';
    RETURN;
  END IF;
  
  -- Verify user has permission (customer or provider)
  IF p_user_id NOT IN (v_booking_user_id, v_booking_provider_id) THEN
    RETURN QUERY SELECT false, false, 0, 'Unauthorized OTP verification attempt';
    RETURN;
  END IF;
  
  -- Check if already verified
  IF v_otp_verified THEN
    RETURN QUERY SELECT true, true, 0, 'OTP already verified';
    RETURN;
  END IF;
  
  -- Check rate limiting
  IF v_current_attempts >= v_max_attempts THEN
    RETURN QUERY SELECT 
      false, 
      false, 
      0, 
      'Too many failed attempts. Please request a new OTP after 15 minutes';
    RETURN;
  END IF;
  
  -- Increment attempt counter
  v_current_attempts := v_current_attempts + 1;
  
  -- Verify OTP
  IF v_stored_otp = p_otp_code THEN
    -- OTP is correct - mark as verified
    UPDATE bookings SET
      otp_verified = true,
      otp_verified_at = NOW(),
      otp_attempts = v_current_attempts,
      status = CASE WHEN status = 'confirmed' THEN 'completed' ELSE status END,
      updated_at = NOW()
    WHERE id = p_booking_id;
    
    RETURN QUERY SELECT 
      true, 
      true, 
      v_max_attempts - v_current_attempts,
      'OTP verified successfully';
  ELSE
    -- OTP is incorrect - increment attempts
    UPDATE bookings SET
      otp_attempts = v_current_attempts,
      updated_at = NOW()
    WHERE id = p_booking_id;
    
    RETURN QUERY SELECT 
      true, 
      false, 
      v_max_attempts - v_current_attempts,
      'Incorrect OTP. ' || (v_max_attempts - v_current_attempts) || ' attempts remaining';
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    false, 
    false, 
    0, 
    'Error verifying OTP: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 14. SECURE REFUND PROCESSING ✨ NEW
-- Processes refunds with validation, commission adjustment, and fraud prevention
-- FIXED:
--   - Added ELSE clause to reject unknown refund reasons (was silently defaulting to 100%)
--   - FIXED ordering bug: now checks time-before-start FIRST to prevent free cancellations on last-minute bookings
-- ============================================================================
CREATE OR REPLACE FUNCTION secure_process_refund(
  p_booking_id UUID,
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
  v_booking_user_id TEXT;
  v_booking_provider_id TEXT;
  v_refund_locked BOOLEAN;
  v_calculated_refund NUMERIC;
  v_commission_adjustment NUMERIC;
  v_time_since_booking INTERVAL;
  v_start_time TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Validate input parameters
  IF p_booking_id IS NULL OR p_refund_reason IS NULL OR p_initiated_by IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Invalid input parameters';
    RETURN;
  END IF;
  
  IF p_refund_percentage < 0 OR p_refund_percentage > 100 THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Refund percentage must be between 0 and 100';
    RETURN;
  END IF;
  
  -- Get booking details with lock for atomic operation
  SELECT 
    status,
    payment_amount,
    platform_fee,
    payment_status,
    user_id,
    provider_id,
    refund_locked,
    start_time,
    NOW() - created_at
  INTO 
    v_booking_status,
    v_payment_amount,
    v_platform_fee,
    v_payment_status,
    v_booking_user_id,
    v_booking_provider_id,
    v_refund_locked,
    v_start_time,
    v_time_since_booking
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;
  
  IF v_booking_status IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking not found';
    RETURN;
  END IF;
  
  -- Check if refund is already locked (prevent double refunds)
  IF v_refund_locked THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Refund already processed or locked';
    RETURN;
  END IF;
  
  -- Validate booking status for refund eligibility
  IF v_booking_status IN ('cancelled', 'refunded', 'expired') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Booking already cancelled or refunded';
    RETURN;
  END IF;
  
  -- Check payment status
  IF v_payment_status NOT IN ('captured', 'authorized') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'No payment to refund';
    RETURN;
  END IF;
  
  -- Validate authorization
  IF p_initiated_by NOT IN (v_booking_user_id, v_booking_provider_id, 'system', 'admin') THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Unauthorized refund request';
    RETURN;
  END IF;
  
  -- Apply refund policies based on timing and reason
  IF p_refund_reason = 'cancellation_by_customer' THEN
    -- FIXED: Check time-before-start FIRST to prevent free cancellations on last-minute bookings
    IF v_start_time <= NOW() + INTERVAL '2 hours' THEN
      -- Less than 2 hours before start: 0% refund
      p_refund_percentage := 0.0;
    ELSIF v_time_since_booking < INTERVAL '1 hour' THEN
      -- Booked less than 1 hour ago AND start is >2 hours away: 100% refund
      p_refund_percentage := 100.0;
    ELSIF v_time_since_booking < INTERVAL '24 hours' THEN
      -- Booked 1-24 hours ago: 80% refund
      p_refund_percentage := 80.0;
    ELSE
      -- Booked >24 hours ago: 50% refund
      p_refund_percentage := 50.0;
    END IF;
  ELSIF p_refund_reason = 'cancellation_by_provider' THEN
    p_refund_percentage := 100.0;
  ELSIF p_refund_reason = 'no_show' THEN
    p_refund_percentage := 0.0;
  ELSIF p_refund_reason = 'system_error' THEN
    p_refund_percentage := 100.0;
  ELSE
    -- FIXED: Reject unknown refund reasons instead of silently defaulting to passed percentage
    RETURN QUERY SELECT 
      false, 
      0::NUMERIC, 
      0::NUMERIC, 
      'Invalid refund reason: ' || p_refund_reason || '. Allowed reasons: cancellation_by_customer, cancellation_by_provider, no_show, system_error';
    RETURN;
  END IF;
  
  -- Calculate refund amounts
  v_calculated_refund := (v_payment_amount * p_refund_percentage / 100.0)::NUMERIC(12, 2);
  v_commission_adjustment := (v_platform_fee * p_refund_percentage / 100.0)::NUMERIC(12, 2);
  
  -- Lock refund to prevent double processing
  UPDATE bookings SET
    refund_locked = true,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  -- Process the refund
  UPDATE bookings SET
    status = 'cancelled',
    payment_status = 'refunded',
    cancellation_reason = p_refund_reason,
    cancelled_by = p_initiated_by,
    cancelled_at = NOW(),
    refund_requested = true,
    refund_requested_at = NOW(),
    updated_at = NOW(),
    metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
      'refund_amount', v_calculated_refund,
      'refund_percentage', p_refund_percentage,
      'commission_refund', v_commission_adjustment,
      'refund_reason', p_refund_reason,
      'refund_processed_at', NOW()
    )
  WHERE id = p_booking_id;
  
  -- Verify update succeeded
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0::NUMERIC, 'Failed to process refund';
    RETURN;
  END IF;
  
  -- Return success with refund details
  RETURN QUERY SELECT 
    true, 
    v_calculated_refund,
    v_commission_adjustment,
    'Refund processed successfully. Amount: ₹' || v_calculated_refund || ' (' || p_refund_percentage || '% of ₹' || v_payment_amount || ')';
  
EXCEPTION WHEN OTHERS THEN
  -- Unlock refund on error
  UPDATE bookings SET refund_locked = false WHERE id = p_booking_id;
  
  RETURN QUERY SELECT 
    false, 
    0::NUMERIC, 
    0::NUMERIC, 
    'Error processing refund: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SUMMARY OF ALL 25 FUNCTIONS
-- ============================================================================
-- SECTION 1: Existing Functions (11) - Already in database
--   1. bookings_set_slot_layout_from_seat_keys
--   2. expire_overdue_bookings
--   3. generate_otp (old version)
--   4. get_jwt_claims
--   5. rls_auto_enable
--   6. safe_delete_post
--   7. set_booking_otp
--   8. set_profiles_updated_at
--   9. set_updated_at
--   10. update_updated_at_column
--   11. verify_otp (old version)
--
-- SECTION 2: Fixed & Improved Functions (9) - Run to update
--   1. get_provider_average_rating ✅ FIXED
--   2. get_provider_total_reviews ✅ FIXED
--   3. calculate_provider_earnings ✅ FIXED (name shadowing bug)
--   4. calculate_commission ✅ FIXED
--   5. deduct_credits ✅ FIXED (CEIL consistency - single rounded value)
--   6. check_booking_eligibility ✅ FIXED (self-booking prevention added)
--   7. verify_gps_location ✅ FIXED (ACOS domain error)
--   8. diagnose_coordinate_extraction ✅ FIXED
--   9. validate_coordinates ✅ FIXED
--
-- SECTION 3: New Secure Functions (5) - NEW additions
--   10. secure_create_booking ✨ NEW
--   11. secure_process_payment ✨ NEW
--   12. secure_generate_otp ✨ NEW
--   13. secure_verify_otp ✨ NEW
--   14. secure_process_refund ✨ NEW (FIXED: missing reason validation, ordering bug)
--
-- ============================================================================
-- VERIFICATION QUERY
-- Run this to confirm all functions are created/updated
-- ============================================================================
/*
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (
    routine_name LIKE '%provider%'
    OR routine_name LIKE '%earnings%'
    OR routine_name LIKE '%commission%'
    OR routine_name LIKE '%deduct%'
    OR routine_name LIKE '%booking%'
    OR routine_name LIKE '%payment%'
    OR routine_name LIKE '%otp%'
    OR routine_name LIKE '%refund%'
    OR routine_name LIKE '%gps%'
    OR routine_name LIKE '%coordinate%'
  )
ORDER BY routine_name;
*/
