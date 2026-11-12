-- ============================================================================
-- DROP UUID OVERLOADS - FINAL STEP
-- ============================================================================
-- UUID versions confirmed still present in public schema
-- This removes them so app can use TEXT/BIGINT versions
-- ============================================================================

-- 1. Drop secure_create_booking UUID overload
DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;

-- 2. Drop secure_process_payment UUID overload
DROP FUNCTION IF EXISTS public.secure_process_payment(
  p_booking_id UUID,
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT
) CASCADE;

-- 3. Drop secure_generate_otp UUID overload
DROP FUNCTION IF EXISTS public.secure_generate_otp(
  p_booking_id UUID,
  p_expiry_minutes INTEGER
) CASCADE;

-- 4. Drop secure_verify_otp UUID overload
DROP FUNCTION IF EXISTS public.secure_verify_otp(
  p_booking_id UUID,
  p_otp_code TEXT,
  p_user_id TEXT
) CASCADE;

-- 5. Drop secure_process_refund UUID overload
DROP FUNCTION IF EXISTS public.secure_process_refund(
  p_booking_id UUID,
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC
) CASCADE;

-- ============================================================================
-- VERIFY - Run this after DROP to confirm UUID versions are gone
-- ============================================================================

SELECT 
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('secure_create_booking', 'secure_process_payment', 
                     'secure_generate_otp', 'secure_verify_otp', 
                     'secure_process_refund')
  AND n.nspname = 'public'
ORDER BY p.proname, args;

-- Expected result: 5 rows only (no UUID)
-- secure_create_booking    | p_post_id text, ...
-- secure_process_payment   | p_booking_id bigint, ...
-- secure_generate_otp      | p_booking_id bigint, ...
-- secure_verify_otp        | p_booking_id bigint, ...
-- secure_process_refund    | p_booking_id bigint, ...
