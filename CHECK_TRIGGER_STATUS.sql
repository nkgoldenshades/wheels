-- ============================================
-- CHECK IF OTP TRIGGER IS INSTALLED
-- ============================================

-- 1. Check if functions exist
SELECT 'Checking functions...' as step;
SELECT 
  proname as function_name,
  prosecdef as is_security_definer,
  provolatile as volatility
FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp')
ORDER BY proname;

-- 2. Check if trigger exists
SELECT 'Checking trigger...' as step;
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  tgrelid::regclass as table_name,
  pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgname = 'booking_otp_trigger';

-- 3. Check trigger on bookings table
SELECT 'All triggers on bookings table...' as step;
SELECT 
  tgname as trigger_name,
  tgenabled as enabled
FROM pg_trigger 
WHERE tgrelid = 'public.bookings'::regclass
  AND NOT tgisinternal;

-- 4. Test OTP generation manually
SELECT 'Testing OTP generation function...' as step;
SELECT generate_otp() as test_otp;

-- 5. Check if trigger fires on INSERT
SELECT 'Testing trigger on INSERT...' as step;
-- This will show if trigger is working
