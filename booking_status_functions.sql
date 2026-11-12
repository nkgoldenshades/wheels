-- ============================================================================
-- BOOKING STATUS MANAGEMENT FUNCTIONS
-- ============================================================================
-- These functions handle all booking status transitions with proper validation
-- Run this entire file in Supabase SQL Editor
-- ============================================================================

-- 1. ACCEPT BOOKING
-- Provider accepts a pending booking
CREATE OR REPLACE FUNCTION accept_booking(
  booking_id BIGINT,
  user_id UUID
)
RETURNS json AS $$
DECLARE
  booking_row RECORD;
BEGIN
  -- Get the booking
  SELECT * INTO booking_row 
  FROM bookings 
  WHERE id = booking_id;

  -- Validate: booking exists
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking not found'
    );
  END IF;

  -- Validate: user is the provider
  IF booking_row.profile_provider_id != user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only the provider can accept this booking'
    );
  END IF;

  -- Validate: booking is in pending status
  IF booking_row.status != 'pending' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking is not in pending status'
    );
  END IF;

  -- Update status
  UPDATE bookings
  SET status = 'accepted',
      updated_at = NOW()
  WHERE id = booking_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Booking accepted successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. REJECT BOOKING
-- Provider rejects a pending booking
CREATE OR REPLACE FUNCTION reject_booking(
  booking_id BIGINT,
  user_id UUID
)
RETURNS json AS $$
DECLARE
  booking_row RECORD;
BEGIN
  -- Get the booking
  SELECT * INTO booking_row 
  FROM bookings 
  WHERE id = booking_id;

  -- Validate: booking exists
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking not found'
    );
  END IF;

  -- Validate: user is the provider
  IF booking_row.profile_provider_id != user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only the provider can reject this booking'
    );
  END IF;

  -- Validate: booking is in pending status
  IF booking_row.status != 'pending' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking is not in pending status'
    );
  END IF;

  -- Update status
  UPDATE bookings
  SET status = 'rejected',
      updated_at = NOW()
  WHERE id = booking_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Booking rejected successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. REFUND BOOKING
-- Provider or customer initiates a refund
CREATE OR REPLACE FUNCTION refund_booking(
  booking_id BIGINT,
  user_id UUID
)
RETURNS json AS $$
DECLARE
  booking_row RECORD;
BEGIN
  -- Get the booking
  SELECT * INTO booking_row 
  FROM bookings 
  WHERE id = booking_id;

  -- Validate: booking exists
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking not found'
    );
  END IF;

  -- Validate: user is provider or customer
  IF booking_row.profile_provider_id != user_id 
     AND booking_row.profile_customer_id != user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not authorized to refund this booking'
    );
  END IF;

  -- Update status
  UPDATE bookings
  SET status = 'refunded',
      updated_at = NOW()
  WHERE id = booking_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Booking refunded successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. CANCEL BOOKING
-- Customer or provider cancels a booking
CREATE OR REPLACE FUNCTION cancel_booking(
  booking_id BIGINT,
  user_id UUID,
  cancelled_by TEXT -- 'customer' or 'provider'
)
RETURNS json AS $$
DECLARE
  booking_row RECORD;
  new_status TEXT;
BEGIN
  -- Get the booking
  SELECT * INTO booking_row 
  FROM bookings 
  WHERE id = booking_id;

  -- Validate: booking exists
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Booking not found'
    );
  END IF;

  -- Determine who is cancelling
  IF cancelled_by = 'customer' THEN
    IF booking_row.profile_customer_id != user_id THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Not authorized'
      );
    END IF;
    new_status := 'cancelled_by_customer';
  ELSIF cancelled_by = 'provider' THEN
    IF booking_row.profile_provider_id != user_id THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Not authorized'
      );
    END IF;
    new_status := 'cancelled_by_provider';
  ELSE
    new_status := 'cancelled';
  END IF;

  -- Validate: booking can be cancelled
  IF booking_row.status IN ('completed', 'expired', 'refunded') THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Cannot cancel a ' || booking_row.status || ' booking'
    );
  END IF;

  -- Update status
  UPDATE bookings
  SET status = new_status,
      updated_at = NOW()
  WHERE id = booking_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Booking cancelled successfully',
    'status', new_status
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. EXPIRE OVERDUE BOOKINGS (Updated)
-- Auto-expire bookings that passed end_time without OTP verification
CREATE OR REPLACE FUNCTION expire_overdue_bookings()
RETURNS json AS $$
DECLARE
  expired_count INT;
BEGIN
  UPDATE bookings
  SET status = 'expired'
  WHERE status IN ('pending', 'accepted', 'confirmed', 'in_progress')
    AND otp_verified = FALSE
    AND end_time < NOW();
  
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  
  RETURN json_build_object('expired_count', expired_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT EXECUTE PERMISSIONS (Run this if you have RLS enabled)
-- ============================================================================
-- GRANT EXECUTE ON FUNCTION accept_booking TO authenticated;
-- GRANT EXECUTE ON FUNCTION reject_booking TO authenticated;
-- GRANT EXECUTE ON FUNCTION refund_booking TO authenticated;
-- GRANT EXECUTE ON FUNCTION cancel_booking TO authenticated;
-- GRANT EXECUTE ON FUNCTION expire_overdue_bookings TO authenticated;

-- ============================================================================
-- TEST THE FUNCTIONS (Optional)
-- ============================================================================
-- SELECT accept_booking(123, 'user-uuid-here'::uuid);
-- SELECT reject_booking(123, 'user-uuid-here'::uuid);
-- SELECT refund_booking(123, 'user-uuid-here'::uuid);
-- SELECT cancel_booking(123, 'user-uuid-here'::uuid, 'customer');
-- SELECT expire_overdue_bookings();
