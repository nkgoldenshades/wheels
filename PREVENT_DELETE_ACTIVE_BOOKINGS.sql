-- ============================================================================
-- SAFE POST DELETE — run in Supabase SQL Editor
-- Auto-expires overdue bookings before checking, so once post.end_time
-- passes and deadline_time (end_time + 2h) passes, delete is unblocked.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.safe_delete_post(
  p_post_id    TEXT,
  p_profile_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_active_count INTEGER;
  v_post_exists  BOOLEAN;
BEGIN
  -- Ownership check
  SELECT EXISTS (
    SELECT 1 FROM public.posts
    WHERE id::text = p_post_id
      AND profile_id = p_profile_id
  ) INTO v_post_exists;

  IF NOT v_post_exists THEN
    RETURN jsonb_build_object('success', false, 'code', 'not_found',
      'message', 'Post not found or you do not own it.');
  END IF;

  -- Auto-expire overdue bookings on this post first
  UPDATE public.bookings
  SET status = 'expired', updated_at = NOW()
  WHERE post_id::text = p_post_id
    AND deadline_time IS NOT NULL
    AND deadline_time < NOW()
    AND status IN ('pending','accepted','confirmed','in_progress');

  -- Count truly active bookings (deadline not yet passed)
  SELECT COUNT(*) INTO v_active_count
  FROM public.bookings
  WHERE post_id::text = p_post_id
    AND status NOT IN (
      'completed','rejected','refunded',
      'cancelled','cancelled_by_customer','cancelled_by_provider',
      'no_show','disputed','expired'
    );

  IF v_active_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'has_active_bookings',
      'active_count', v_active_count,
      'message', format('Cannot delete: %s active booking(s) still within deadline.', v_active_count)
    );
  END IF;

  DELETE FROM public.posts
  WHERE id::text = p_post_id AND profile_id = p_profile_id;

  RETURN jsonb_build_object('success', true, 'code', 'deleted',
    'message', 'Post deleted successfully.');
END;
$func$;

GRANT EXECUTE ON FUNCTION public.safe_delete_post(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_delete_post(TEXT, TEXT) TO anon;


-- Trigger: same logic for direct DELETE attempts
CREATE OR REPLACE FUNCTION public.trg_prevent_post_delete_with_active_bookings()
RETURNS TRIGGER LANGUAGE plpgsql AS $func$
DECLARE v_active_count INTEGER;
BEGIN
  -- Auto-expire overdue bookings first
  UPDATE public.bookings
  SET status = 'expired', updated_at = NOW()
  WHERE post_id::text = OLD.id::text
    AND deadline_time IS NOT NULL
    AND deadline_time < NOW()
    AND status IN ('pending','accepted','confirmed','in_progress');

  SELECT COUNT(*) INTO v_active_count
  FROM public.bookings
  WHERE post_id::text = OLD.id::text
    AND status NOT IN (
      'completed','rejected','refunded',
      'cancelled','cancelled_by_customer','cancelled_by_provider',
      'no_show','disputed','expired'
    );

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'ACTIVE_BOOKINGS: % active booking(s) still within deadline.', v_active_count
      USING ERRCODE = 'P0001';
  END IF;
  RETURN OLD;
END;
$func$;

DROP TRIGGER IF EXISTS prevent_post_delete_with_active_bookings ON public.posts;
CREATE TRIGGER prevent_post_delete_with_active_bookings
  BEFORE DELETE ON public.posts FOR EACH ROW
  EXECUTE FUNCTION public.trg_prevent_post_delete_with_active_bookings();


-- Same for user_posts
CREATE OR REPLACE FUNCTION public.trg_prevent_user_post_delete_with_active_bookings()
RETURNS TRIGGER LANGUAGE plpgsql AS $func$
DECLARE v_active_count INTEGER;
BEGIN
  UPDATE public.bookings
  SET status = 'expired', updated_at = NOW()
  WHERE post_id::text = OLD.id::text
    AND deadline_time IS NOT NULL
    AND deadline_time < NOW()
    AND status IN ('pending','accepted','confirmed','in_progress');

  SELECT COUNT(*) INTO v_active_count
  FROM public.bookings
  WHERE post_id::text = OLD.id::text
    AND status NOT IN (
      'completed','rejected','refunded',
      'cancelled','cancelled_by_customer','cancelled_by_provider',
      'no_show','disputed','expired'
    );

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'ACTIVE_BOOKINGS: % active booking(s) still within deadline.', v_active_count
      USING ERRCODE = 'P0001';
  END IF;
  RETURN OLD;
END;
$func$;

DROP TRIGGER IF EXISTS prevent_user_post_delete_with_active_bookings ON public.user_posts;
CREATE TRIGGER prevent_user_post_delete_with_active_bookings
  BEFORE DELETE ON public.user_posts FOR EACH ROW
  EXECUTE FUNCTION public.trg_prevent_user_post_delete_with_active_bookings();


-- Test:
-- SELECT public.safe_delete_post('your-post-id', 'your-profile-id');
