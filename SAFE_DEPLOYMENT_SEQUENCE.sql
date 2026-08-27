-- ════════════════════════════════════════════════════════════════════════════════
-- SAFE DEPLOYMENT SEQUENCE FOR QUICKOHUNT SECURE FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════════
-- 
-- CRITICAL: This must be run in TWO SEPARATE STEPS
-- 
-- STEP 1: Deploy the correct TEXT/BIGINT versions first
--         File: SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql
--         
-- STEP 2: Then remove the UUID versions
--         File: This file (run this query block only AFTER step 1)
--
-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFY BEFORE PROCEEDING
-- ════════════════════════════════════════════════════════════════════════════════

-- Run this first to see current state:
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

-- Expected BEFORE this script:
-- ┌──────────────────────────────────────────────────────────────┐
-- │ You should see BOTH UUID and TEXT versions for each function:│
-- │                                                                │
-- │ secure_create_booking    | p_post_id uuid, ...        ← OLD  │
-- │ secure_create_booking    | p_post_id text, ...        ← NEW  │
-- │ secure_process_payment   | p_booking_id uuid, ...     ← OLD  │
-- │ secure_process_payment   | p_booking_id bigint, ...   ← NEW  │
-- │ ... (and so on for all 5)                              │
-- │                                                                │
-- │ If you DON'T see both versions, STOP!                       │
-- │ First deploy SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql          │
-- └──────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════════════════
-- ONLY RUN BELOW IF YOU SEE BOTH UUID AND TEXT VERSIONS ABOVE
-- ════════════════════════════════════════════════════════════════════════════════

-- ⚠️  WARNING: Only proceed if:
--    1. You see TWO versions for each function above (UUID + TEXT)
--    2. You successfully deployed SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql
--    3. You understand you're removing the UUID versions

-- ════════════════════════════════════════════════════════════════════════════════
-- STEP: Remove UUID Versions (only safe after TEXT versions exist)
-- ════════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_process_payment(
  p_booking_id UUID,
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_generate_otp(
  p_booking_id UUID,
  p_expiry_minutes INTEGER
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_verify_otp(
  p_booking_id UUID,
  p_otp_code TEXT,
  p_user_id TEXT
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_process_refund(
  p_booking_id UUID,
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC
) CASCADE;

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFY CLEANUP
-- ════════════════════════════════════════════════════════════════════════════════

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

-- Expected AFTER running DROP statements:
-- ┌──────────────────────────────────────────────────────────────┐
-- │ You should see ONLY TEXT versions (UUID removed):            │
-- │                                                                │
-- │ secure_create_booking    | p_post_id text, ...        ✅     │
-- │ secure_process_payment   | p_booking_id bigint, ...   ✅     │
-- │ secure_generate_otp      | p_booking_id bigint, ...   ✅     │
-- │ secure_verify_otp        | p_booking_id bigint, ...   ✅     │
-- │ secure_process_refund    | p_booking_id bigint, ...   ✅     │
-- │                                                                │
-- │ Total: 5 rows (one per function)                            │
-- │ All with TEXT/BIGINT parameters (no UUID) ✅                │
-- └──────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════════════════════════
-- SUCCESS CRITERIA
-- ════════════════════════════════════════════════════════════════════════════════
-- 
-- ✅ Previous verification showed both UUID and TEXT versions
-- ✅ Dropped 5 UUID functions without errors
-- ✅ Final verification shows only 5 TEXT/BIGINT functions
-- ✅ No "uuid" string anywhere in the function arguments
--
-- If all above are true: DEPLOYMENT SUCCESSFUL ✅
--
-- Next: Restart your app and test booking creation
-- ════════════════════════════════════════════════════════════════════════════════
