-- ============================================================================
-- UPDATED: Allow deletion of posts AFTER end_time (not after deadline_time)
-- Users can delete expired posts immediately
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
  v_end_time     TIMESTAMPTZ;
BEGIN
  -- Ownership check and get end_time
  SELECT EXISTS (
    SELECT 1 FROM public.posts
    WHERE id::text = p_post_id
      AND profile_id = p_profile_id
  ), end_time INTO v_post_exists, v_end_time
  FROM public.posts
  WHERE id::text = p_post_id
    AND profile_id = p_profile_id;

  IF NOT v_post_exists THEN
    RETURN jsonb_build_object('success', false, 'code', 'not_found',
      'message', 'Post not found or you do not own it.');
  END IF;

  -- If post has expired (end_time passed), auto-cancel all active bookings
  IF v_end_time < NOW() THEN
    UPDATE public.bookings
    SET status = 'expired', updated_at = NOW()
    WHERE post_id::text = p_post_id
      AND status IN ('pending','accepted','confirmed','in_progress');
  END IF;

  -- Count truly active bookings (only if post NOT expired)
  -- Once post expires, we allow deletion regardless of bookings
  IF v_end_time >= NOW() THEN
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
        'message', format('Cannot delete: %s active booking(s). Wait until post expires.', v_active_count)
      );
    END IF;
  END IF;

  -- Delete the post
  DELETE FROM public.posts
  WHERE id::text = p_post_id AND profile_id = p_profile_id;

  RETURN jsonb_build_object('success', true, 'code', 'deleted',
    'message', 'Post deleted successfully.');
END;
$func$;

GRANT EXECUTE ON FUNCTION public.safe_delete_post(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_delete_post(TEXT, TEXT) TO anon;


-- Update trigger to match
CREATE OR REPLACE FUNCTION public.trg_prevent_post_delete_with_active_bookings()
RETURNS TRIGGER LANGUAGE plpgsql AS $func$
DECLARE 
  v_active_count INTEGER;
  v_end_time TIMESTAMPTZ;
BEGIN
  v_end_time := OLD.end_time;
  
  -- If post expired, auto-cancel active bookings
  IF v_end_time < NOW() THEN
    UPDATE public.bookings
    SET status = 'expired', updated_at = NOW()
    WHERE post_id::text = OLD.id::text
      AND status IN ('pending','accepted','confirmed','in_progress');
    
    -- Allow deletion
    RETURN OLD;
  END IF;

  -- Post NOT expired yet - check for active bookings
  SELECT COUNT(*) INTO v_active_count
  FROM public.bookings
  WHERE post_id::text = OLD.id::text
    AND status NOT IN (
      'completed','rejected','refunded',
      'cancelled','cancelled_by_customer','cancelled_by_provider',
      'no_show','disputed','expired'
    );

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'ACTIVE_BOOKINGS: Cannot delete post with % active booking(s). Wait until post expires.', v_active_count
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
DECLARE 
  v_active_count INTEGER;
  v_end_time TIMESTAMPTZ;
BEGIN
  v_end_time := OLD.end_time;
  
  IF v_end_time < NOW() THEN
    UPDATE public.bookings
    SET status = 'expired', updated_at = NOW()
    WHERE post_id::text = OLD.id::text
      AND status IN ('pending','accepted','confirmed','in_progress');
    RETURN OLD;
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM public.bookings
  WHERE post_id::text = OLD.id::text
    AND status NOT IN (
      'completed','rejected','refunded',
      'cancelled','cancelled_by_customer','cancelled_by_provider',
      'no_show','disputed','expired'
    );

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'ACTIVE_BOOKINGS: Cannot delete post with % active booking(s). Wait until post expires.', v_active_count
      USING ERRCODE = 'P0001';
  END IF;
  RETURN OLD;
END;
$func$;

DROP TRIGGER IF EXISTS prevent_user_post_delete_with_active_bookings ON public.user_posts;
CREATE TRIGGER prevent_user_post_delete_with_active_bookings
  BEFORE DELETE ON public.user_posts FOR EACH ROW
  EXECUTE FUNCTION public.trg_prevent_user_post_delete_with_active_bookings();
