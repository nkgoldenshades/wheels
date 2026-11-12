-- ============================================================================
-- CRITICAL: REMOVE ALL OLD UUID OVERLOADS OF SECURE FUNCTIONS
-- ============================================================================
-- Problem: Multiple versions exist for ALL 5 secure functions:
--   - UUID versions (OLD, WRONG) ❌
--   - TEXT versions (NEW, CORRECT) ✅
--
-- Postgres matches UUID versions first, causing:
--   "invalid input syntax for type uuid: POST_ID_HERE"
--
-- Solution: DROP all UUID overloads, keep only TEXT versions
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 1: LIST ALL OVERLOADS BEFORE DELETION
-- ════════════════════════════════════════════════════════════════════════════

-- Check secure_create_booking
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('secure_create_booking', 'secure_process_payment', 
                     'secure_generate_otp', 'secure_verify_otp', 
                     'secure_process_refund')
ORDER BY p.proname, args;

-- Expected: Multiple entries for each function (UUID + TEXT versions)

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 2: DROP ALL UUID OVERLOADS
-- ════════════════════════════════════════════════════════════════════════════

-- 1. Drop UUID version of secure_create_booking
DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;

-- 2. Drop UUID version of secure_process_payment
DROP FUNCTION IF EXISTS public.secure_process_payment(
  p_booking_id UUID,
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT
) CASCADE;

-- 3. Drop UUID version of secure_generate_otp
DROP FUNCTION IF EXISTS public.secure_generate_otp(
  p_booking_id UUID,
  p_expiry_minutes INTEGER
) CASCADE;

-- 4. Drop UUID version of secure_verify_otp
DROP FUNCTION IF EXISTS public.secure_verify_otp(
  p_booking_id UUID,
  p_otp_code TEXT,
  p_user_id TEXT
) CASCADE;

-- 5. Drop UUID version of secure_process_refund
DROP FUNCTION IF EXISTS public.secure_process_refund(
  p_booking_id UUID,
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC
) CASCADE;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 3: VERIFY ONLY TEXT VERSIONS REMAIN
-- ════════════════════════════════════════════════════════════════════════════

SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('secure_create_booking', 'secure_process_payment', 
                     'secure_generate_otp', 'secure_verify_otp', 
                     'secure_process_refund')
ORDER BY p.proname, args;

-- Expected result: Exactly 5 entries (one per function, all with TEXT parameters)
-- Examples:
--   secure_create_booking      | p_post_id text, p_user_id text, ...
--   secure_generate_otp        | p_booking_id bigint, p_expiry_minutes integer
--   secure_process_payment     | p_booking_id bigint, p_payment_amount numeric, ...
--   secure_process_refund      | p_booking_id bigint, p_refund_reason text, ...
--   secure_verify_otp          | p_booking_id bigint, p_otp_code text, ...

-- ════════════════════════════════════════════════════════════════════════════
-- EXPLANATION
-- ════════════════════════════════════════════════════════════════════════════
--
-- Why we have UUID overloads:
--   You deployed multiple SQL files with UUID versions:
--   - create_security_functions.sql (UUID)
--   - SECURITY_FUNCTIONS_CORRECTED.sql (UUID)
--   - ALL_DATABASE_FUNCTIONS_COMPLETE.sql (UUID)
--
--   Then deployed the correct version:
--   - SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql (TEXT)
--
-- Why CREATE OR REPLACE didn't remove them:
--   CREATE OR REPLACE only replaces functions with IDENTICAL signatures.
--   Different signatures = new overload, not replacement.
--
-- Why UUID version gets called first:
--   Postgres tries to match parameters in a specific order:
--   1. Best exact match
--   2. Implicit casts (TEXT to UUID is attempted)
--   3. Falls back to TEXT version if UUID fails
--
--   So when you call with 'post-id' (TEXT):
--   → Postgres tries: 'post-id'::UUID ✗ FAILS before trying TEXT version
--
-- Why we drop UUID versions:
--   Once removed, all calls match the TEXT version ✓
--
-- ════════════════════════════════════════════════════════════════════════════
