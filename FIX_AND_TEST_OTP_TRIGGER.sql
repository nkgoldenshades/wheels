-- ============================================
-- FIX OTP TRIGGER FOR BOOKINGS TABLE
-- ============================================
-- This fixes the delimiter issue in the existing trigger
-- and provides comprehensive testing
-- ============================================

-- Step 1: Drop existing broken trigger and function
DROP TRIGGER IF EXISTS bookings_generate_otp ON public.bookings;
DROP TRIGGER IF EXISTS booking_otp_trigger ON public.bookings;
DROP FUNCTION IF EXISTS generate_booking_otp();
DROP FUNCTION IF EXISTS set_booking_otp();
DROP FUNCTION IF EXISTS generate_otp();

-- Step 2: Create OTP generation function (FIXED with $$)
CREATE OR REPLACE FUNCTION generate_otp()
RETURNS TEXT AS $$
BEGIN
  -- Generate random 6-digit number (100000 to 999999)
  RETURN LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create trigger function (FIXED with $$)
CREATE OR REPLACE FUNCTION set_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Only generate OTP if not provided (NULL or empty)
  IF NEW.otp_code IS NULL OR NEW.otp_code = '' THEN
    NEW.otp_code := generate_otp();
    RAISE NOTICE 'Generated OTP: % for booking ID: %', NEW.otp_code, NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create trigger
CREATE TRIGGER booking_otp_trigger
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_otp();

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- 1. Check if functions exist
SELECT 
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('generate_otp', 'set_booking_otp')
ORDER BY routine_name;

-- 2. Check if trigger exists
SELECT 
  tg.tgname as trigger_name,
  c.relname as table_name,
  CASE tg.tgenabled
    WHEN 'O' THEN 'enabled'
    WHEN 'D' THEN 'disabled'
    ELSE 'unknown'
  END as status,
  pg_get_triggerdef(tg.oid) as definition
FROM pg_trigger tg
JOIN pg_class c ON c.oid = tg.tgrelid
WHERE c.relname = 'bookings'
  AND tg.tgname = 'booking_otp_trigger'
  AND NOT tg.tgisinternal;

-- ============================================
-- TEST INSERTS
-- ============================================

-- Test 1: Minimal insert (only required fields)
INSERT INTO public.bookings (
  post_id,
  user_id,
  provider_id,
  price_snapshot,
  start_time,
  end_time
) VALUES (
  gen_random_uuid(), -- Random post_id
  'test-user-' || floor(random() * 1000)::text,
  'test-provider-' || floor(random() * 1000)::text,
  100.0,
  now(),
  now() + interval '1 hour'
) RETURNING id, otp_code, status, created_at;

-- Test 2: Full insert with all common fields
INSERT INTO public.bookings (
  post_id,
  user_id,
  provider_id,
  status,
  price_snapshot,
  deposit_snapshot,
  currency_snapshot,
  persons_snapshot,
  booking_strategy_snapshot,
  start_time,
  end_time,
  payment_status,
  service_type,
  total_price,
  post_mode_snapshot
) VALUES (
  gen_random_uuid(),
  'test-user-full-' || floor(random() * 1000)::text,
  'test-provider-full-' || floor(random() * 1000)::text,
  'pending',
  150.0,
  0,
  'INR',
  1,
  'instant',
  now() + interval '2 hours',
  now() + interval '4 hours',
  'unpaid',
  'passenger',
  150.0,
  'instant'
) RETURNING id, otp_code, status, service_type, total_price, created_at;

-- ============================================
-- VIEW RECENT BOOKINGS WITH OTP
-- ============================================

SELECT 
  id,
  otp_code,
  status,
  service_type,
  total_price,
  price_snapshot,
  user_id,
  provider_id,
  created_at
FROM public.bookings
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- CLEANUP TEST DATA (Run this after testing)
-- ============================================

-- Uncomment to delete test bookings
-- DELETE FROM public.bookings 
-- WHERE user_id LIKE 'test-user%' 
--   OR provider_id LIKE 'test-provider%';

-- Verify cleanup
-- SELECT COUNT(*) as remaining_test_bookings
-- FROM public.bookings
-- WHERE user_id LIKE 'test-user%' 
--   OR provider_id LIKE 'test-provider%';

-- ============================================
-- EXPECTED RESULTS
-- ============================================
-- After running Test 1 and Test 2, you should see:
-- 
-- id                                   | otp_code | status  | created_at
-- -------------------------------------|----------|---------|------------------
-- 550e8400-e29b-41d4-a716-446655440000 | 123456   | pending | 2026-04-17...
-- 550e8400-e29b-41d4-a716-446655440001 | 789012   | pending | 2026-04-17...
--
-- ✅ If otp_code is filled with 6-digit numbers, the trigger is working!
-- ❌ If otp_code is NULL, check the trigger definition above
-- ============================================
