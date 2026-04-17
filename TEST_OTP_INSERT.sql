-- ============================================
-- TEST OTP GENERATION
-- ============================================
-- Run this AFTER installing the trigger
-- ============================================

-- Test insert with minimal required fields
INSERT INTO public.bookings (
  post_id,
  user_id,
  provider_id,
  price_snapshot,
  start_time,
  end_time,
  service_type,
  total_price
) VALUES (
  gen_random_uuid(),
  'test-user-123',
  'test-provider-456',
  100.0,
  now(),
  now() + interval '1 hour',
  'passenger',
  100.0
) RETURNING id, otp_code, status, created_at;

-- View the result
SELECT 
  id,
  otp_code,
  status,
  service_type,
  total_price,
  user_id,
  provider_id,
  created_at
FROM public.bookings
WHERE user_id = 'test-user-123'
ORDER BY created_at DESC
LIMIT 1;

-- Cleanup test data
DELETE FROM public.bookings WHERE user_id = 'test-user-123';
