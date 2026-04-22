-- ============================================================================
-- AUTO-EXPIRE OVERDUE BOOKINGS
-- Run in Supabase SQL Editor.
--
-- Logic:
--   deadline_time = end_time + 2 hours (grace period)
--   If now > deadline_time AND status is still active → mark as expired
--
-- Two parts:
--   1. Function that expires overdue bookings (call manually or via cron)
--   2. Trigger that sets deadline_time automatically on INSERT
-- ============================================================================

-- ── 1. Add deadline_time column if it doesn't exist ──────────────────────────

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS deadline_time TIMESTAMPTZ;

-- Backfill existing rows: deadline = end_time + 2 hours
UPDATE public.bookings
SET deadline_time = end_time + INTERVAL '2 hours'
WHERE deadline_time IS NULL
  AND end_time IS NOT NULL;

-- ── 2. Trigger: auto-set deadline_time on INSERT ─────────────────────────────

CREATE OR REPLACE FUNCTION public.trg_set_booking_deadline()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $func$
BEGIN
  -- Set deadline = end_time + 2 hours grace period
  -- If no end_time, fall back to created_at + 24 hours
  IF NEW.end_time IS NOT NULL THEN
    NEW.deadline_time := NEW.end_time; -- deadline = end_time exactly, no grace period
  ELSIF NEW.deadline_time IS NULL THEN
    NEW.deadline_time := NEW.created_at + INTERVAL '24 hours';
  END IF;
  RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS set_booking_deadline ON public.bookings;
CREATE TRIGGER set_booking_deadline
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_set_booking_deadline();


-- ── 3. Function: expire overdue bookings ─────────────────────────────────────
-- Call this via pg_cron every 15 minutes, or call manually.

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

GRANT EXECUTE ON FUNCTION public.expire_overdue_bookings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_overdue_bookings() TO service_role;


-- ── 4. Schedule with pg_cron (run every 15 minutes) ──────────────────────────
-- Only works if pg_cron extension is enabled in Supabase.
-- Go to: Database → Extensions → enable pg_cron

-- SELECT cron.schedule(
--   'expire-overdue-bookings',
--   '*/15 * * * *',
--   $$ SELECT public.expire_overdue_bookings(); $$
-- );

-- To check scheduled jobs:
-- SELECT * FROM cron.job;

-- To remove the job:
-- SELECT cron.unschedule('expire-overdue-bookings');


-- ── 5. Verify ─────────────────────────────────────────────────────────────────
-- Check which bookings are currently overdue:
-- SELECT id, status, end_time, deadline_time,
--        deadline_time - NOW() AS time_remaining
-- FROM public.bookings
-- WHERE deadline_time < NOW()
--   AND status IN ('pending','accepted','confirmed','in_progress')
-- ORDER BY deadline_time;

-- Run expiry manually right now:
-- SELECT public.expire_overdue_bookings();


-- ============================================================================
-- AUTO-DEACTIVATE EXPIRED POSTS
-- Marks posts as inactive when their end_time has passed.
-- ============================================================================

-- Add post_status column if it doesn't exist
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS post_status TEXT DEFAULT 'active'
  CHECK (post_status IN ('active','ended','paused','full','cancelled'));

-- Backfill: posts with end_time in the past → 'ended'
UPDATE public.posts
SET post_status = 'ended'
WHERE is_active = false
  AND end_time < NOW()
  AND post_status = 'active';

CREATE OR REPLACE FUNCTION public.auto_deactivate_expired_posts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_count INTEGER;
BEGIN
  -- Posts whose end_time passed → mark ended (not just inactive)
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


-- ── Schedule both together every 15 min (requires pg_cron extension) ─────────
-- Database → Extensions → enable pg_cron, then run:

-- SELECT cron.schedule(
--   'auto-maintenance',
--   '*/15 * * * *',
--   $cron$
--     SELECT public.expire_overdue_bookings();
--     SELECT public.auto_deactivate_expired_posts();
--   $cron$
-- );

-- Run manually right now:
-- SELECT public.auto_deactivate_expired_posts();
