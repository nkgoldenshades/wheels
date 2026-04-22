-- ============================================
-- DEBUG OTP ATTEMPTS NOT INCREMENTING
-- ============================================

-- 1. Check the data type of bookings.id
SELECT 
  column_name,
  data_type,
  character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'bookings'
  AND column_name = 'id';

-- 2. Check verify_otp function signature
SELECT 
  proname,
  pg_get_function_arguments(oid) as arguments,
  pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'verify_otp';

-- 3. Test verify_otp with one of your actual bookings
-- Replace 23 with an actual booking ID from your table
SELECT verify_otp(
  23,  -- Use actual booking ID
  (SELECT profile_customer_id FROM bookings WHERE id = 23),
  '999999'  -- Wrong OTP
) as result;

-- 4. Check if attempts incremented
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  profile_customer_id
FROM bookings
WHERE id = 23;

-- 5. Try calling verify_otp with TEXT id (if your id column is TEXT)
SELECT verify_otp(
  23::BIGINT,  -- Explicitly cast to BIGINT
  (SELECT profile_customer_id FROM bookings WHERE id = 23),
  '999999'
) as result;
