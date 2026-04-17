-- ============================================
-- OTP GENERATION TRIGGER FOR BOOKINGS TABLE
-- ============================================
-- This trigger automatically generates a 6-digit OTP
-- when a new booking is created
-- ============================================

-- Step 1: Create function to generate 6-digit OTP
CREATE OR REPLACE FUNCTION generate_otp()
RETURNS TEXT AS $$
BEGIN
  -- Generate random 6-digit number (100000 to 999999)
  RETURN LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Step 2: Create trigger function to set OTP on booking insert
CREATE OR REPLACE FUNCTION set_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Only generate OTP if not provided (NULL)
  IF NEW.otp_code IS NULL OR NEW.otp_code = '' THEN
    NEW.otp_code := generate_otp();
    RAISE NOTICE 'Generated OTP: % for booking', NEW.otp_code;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Drop existing trigger if it exists
DROP TRIGGER IF EXISTS booking_otp_trigger ON bookings;

-- Step 4: Create trigger that runs BEFORE INSERT
CREATE TRIGGER booking_otp_trigger
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_otp();

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify trigger exists
SELECT 
  tg.tgname as trigger_name,
  c.relname as table_name,
  tg.tgenabled as enabled,
  pg_get_triggerdef(tg.oid) as trigger_definition
FROM pg_trigger tg
JOIN pg_class c ON c.oid = tg.tgrelid
WHERE c.relname = 'bookings'
  AND tg.tgname = 'booking_otp_trigger'
  AND NOT tg.tgisinternal;

-- Verify functions exist
SELECT 
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('generate_otp', 'set_booking_otp')
ORDER BY routine_name;

-- ============================================
-- TEST INSERT (Run this to test)
-- ============================================

-- Test 1: Insert without otp_code (should auto-generate)
INSERT INTO bookings (
  profile_customer_id, 
  profile_provider_id, 
  post_id, 
  status, 
  price_snapshot,
  service_type,
  total_price
) VALUES (
  'test-customer-' || floor(random() * 1000)::text,
  'test-provider-' || floor(random() * 1000)::text, 
  'test-post-' || floor(random() * 1000)::text,
  'pending',
  100.0,
  'passenger',
  100.0
) RETURNING id, otp_code, created_at;

-- Test 2: Check the last inserted booking
SELECT 
  id, 
  otp_code, 
  status,
  service_type,
  created_at 
FROM bookings 
ORDER BY created_at DESC 
LIMIT 5;

-- ============================================
-- CLEANUP TEST DATA (Optional)
-- ============================================
-- DELETE FROM bookings 
-- WHERE profile_customer_id LIKE 'test-customer-%'
--   AND profile_provider_id LIKE 'test-provider-%';
