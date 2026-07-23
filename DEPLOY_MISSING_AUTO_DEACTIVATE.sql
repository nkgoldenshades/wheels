-- ============================================================================
-- Deploy ONLY the missing function: auto_deactivate_expired_posts
-- 
-- Your Supabase already has:
-- ✅ expire_overdue_bookings - EXISTS
-- ❌ auto_deactivate_expired_posts - MISSING (this fixes it)
-- ============================================================================

-- Ensure post_status column exists on posts table
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS post_status TEXT DEFAULT 'active'
  CHECK (post_status IN ('active','ended','paused','full','cancelled'));

-- Deploy the missing function
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

-- Verify it was created
SELECT 
  p.proname as function_name,
  n.nspname as schema
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'auto_deactivate_expired_posts'
  AND n.nspname = 'public';

-- Expected: 1 row showing auto_deactivate_expired_posts in public schema
