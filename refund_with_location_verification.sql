-- Enhanced refund function with location verification
-- This function allows customers to get FULL refund (including security deposit)
-- if they were verified at pickup location but provider didn't show up

CREATE OR REPLACE FUNCTION refund_booking_with_location(
  booking_id INTEGER,
  user_id TEXT,
  refund_type TEXT,  -- 'full_with_deposit' or 'standard'
  customer_location_verified BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_deposit_amount NUMERIC;
  v_ride_price NUMERIC;
  v_total_refund NUMERIC;
  v_deposit_returned BOOLEAN := FALSE;
  v_refund_note TEXT;
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = booking_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Booking not found'
    );
  END IF;

  -- Security: Only customer or provider can refund
  IF v_booking.profile_customer_id != user_id 
     AND v_booking.profile_provider_id != user_id THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Unauthorized'
    );
  END IF;

  -- Already refunded?
  IF v_booking.status = 'refunded' THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Already refunded'
    );
  END IF;

  -- Already completed?
  IF v_booking.status = 'completed' THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Cannot refund completed trip'
    );
  END IF;

  -- Calculate amounts (stored in paise/cents, convert to major unit)
  v_deposit_amount := COALESCE(v_booking.deposit_snapshot, 0) / 100.0;
  v_ride_price := v_booking.price_snapshot / 100.0;

  -- Determine refund amount based on verification and user
  IF refund_type = 'full_with_deposit' 
     AND customer_location_verified 
     AND v_booking.profile_customer_id = user_id 
     AND NOT v_booking.otp_verified THEN
    
    -- ✅ FULL REFUND SCENARIO
    -- Customer was at pickup location (GPS verified)
    -- Provider didn't show up (OTP not verified)
    -- → Return EVERYTHING (ride + deposit)
    
    v_total_refund := v_ride_price + v_deposit_amount;
    v_deposit_returned := TRUE;
    v_refund_note := 'Full refund with deposit: Customer location verified, provider no-show';
    
    -- Mark booking as refunded
    UPDATE bookings
    SET 
      status = 'refunded',
      refunded_at = NOW(),
      refund_note = v_refund_note
    WHERE id = booking_id;

    RAISE NOTICE 'Full refund processed: % (ride: %, deposit: %)', 
                 v_total_refund, v_ride_price, v_deposit_amount;

  ELSE
    -- ❌ STANDARD REFUND SCENARIO
    -- Either: customer not at location, OR provider initiated refund, OR OTP verified
    
    IF v_booking.otp_verified THEN
      -- OTP verified = trip started/completed, cannot refund
      RETURN json_build_object(
        'success', FALSE,
        'message', 'Trip started/completed, cannot refund'
      );
    END IF;

    -- Refund ride price only (deposit handled by no-show logic)
    v_total_refund := v_ride_price;
    v_deposit_returned := FALSE;
    
    -- Different note based on who requested
    IF v_booking.profile_customer_id = user_id THEN
      v_refund_note := 'Standard refund: Ride price only (location not verified or deposit forfeited)';
    ELSE
      v_refund_note := 'Provider-initiated refund: Ride price returned to customer';
    END IF;

    UPDATE bookings
    SET 
      status = 'refunded',
      refunded_at = NOW(),
      refund_note = v_refund_note
    WHERE id = booking_id;

    RAISE NOTICE 'Standard refund processed: % (ride price only)', v_total_refund;
  END IF;

  -- Free up slot capacity
  UPDATE slots
  SET remaining_capacity = remaining_capacity + 1
  WHERE id = v_booking.slot_id
    AND remaining_capacity < total_capacity;

  -- Return success with details
  RETURN json_build_object(
    'success', TRUE,
    'message', 'Refund processed successfully',
    'refunded_amount', v_total_refund,
    'deposit_returned', v_deposit_returned,
    'refund_note', v_refund_note
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Refund error: %', SQLERRM;
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Database error: ' || SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION refund_booking_with_location(INTEGER, TEXT, TEXT, BOOLEAN) TO authenticated;

-- Add comment
COMMENT ON FUNCTION refund_booking_with_location IS 
'Enhanced refund function that returns full amount + deposit if customer location was verified but provider did not show up (OTP not entered)';
