-- ============================================================================
-- ACTUAL FIX: Deploy the 2 missing RPC functions to Supabase
-- 
-- These functions are defined in AUTO_EXPIRE_BOOKINGS.sql in your project
-- but were never deployed to your Supabase database.
--
-- Your Flutter app is calling them but getting 404 because they don't exist.
-- ============================================================================

-- STEP 1: Add required column to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS deadline_time TIMESTAMPTZ;

-- Backfill deadline_time for existing bookings
UPDATE public.bookings
SET deadline_time = end_time
WHERE deadline_time IS NULL AND end_time IS NOT NULL;


-- STEP 2: Add required column to posts table
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS post_status TEXT DEFAULT 'active'
  CHECK (post_status IN ('active','ended','paused','full','cancelled'));


-- STEP 3: Deploy RPC Function #1 - expire_overdue_bookings
CREATE OR REPLACE FUNCTION public.expire_overdue_bookings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_expired_count INTEGER;
BEGIN
  UPDATE public.bookings
  SET
    status = 'expired',
    updated_at = NOW()
  WHERE
    deadline_time IS NOT NULL
    AND deadline_time < NOW()
    AND status IN ('pending', 'accepted', 'confirmed', 'in_progress');

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'expired_count', v_expired_count,
    'ran_at', NOW()
  );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.expire_overdue_bookings() 
  TO authenticated, service_role;


-- STEP 4: Deploy RPC Function #2 - auto_deactivate_expired_posts
CREATE OR REPLACE FUNCTION public.auto_deactivate_expired_posts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE public.posts
  SET is_active = false,
      post_status = 'ended',
      updated_at = NOW()
  WHERE is_active = true
    AND end_time < NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'deactivated_posts', v_count,
    'ran_at', NOW()
  );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.auto_deactivate_expired_posts()
  TO authenticated, service_role;


-- STEP 5: Verify functions exist
SELECT 
  p.proname as function_name,
  n.nspname as schema,
  CASE WHEN n.nspname = 'public' THEN '✅ Ready' ELSE '❌ Wrong schema' END as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('expire_overdue_bookings', 'auto_deactivate_expired_posts')
ORDER BY p.proname;

-- Expected: 2 rows, both in public schema
