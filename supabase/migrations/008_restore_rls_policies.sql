-- Restore RLS policies after UUID to TEXT migration

-- =====================================================
-- USERS TABLE
-- =====================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_all" ON public.users
  FOR SELECT USING (true);

CREATE POLICY "users_insert_self" ON public.users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "users_update_self" ON public.users
  FOR UPDATE USING ((auth.uid())::text = id);

-- =====================================================
-- VEHICLES TABLE
-- =====================================================
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vehicles_select_all" ON public.vehicles
  FOR SELECT USING (true);

CREATE POLICY "vehicles_insert_self" ON public.vehicles
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "vehicles_update_self" ON public.vehicles
  FOR UPDATE USING ((auth.uid())::text = user_id);

CREATE POLICY "vehicles_delete_self" ON public.vehicles
  FOR DELETE USING ((auth.uid())::text = user_id);

-- =====================================================
-- SLOTS TABLE
-- =====================================================
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "slots_select_all" ON public.slots
  FOR SELECT USING (true);

CREATE POLICY "slots_insert_self" ON public.slots
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "slots_update_self" ON public.slots
  FOR UPDATE USING ((auth.uid())::text = user_id);

CREATE POLICY "slots_delete_self" ON public.slots
  FOR DELETE USING ((auth.uid())::text = user_id);

-- =====================================================
-- BOOKINGS TABLE
-- =====================================================
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookings_select_own" ON public.bookings
  FOR SELECT USING (
    (auth.uid())::text = user_id OR 
    (auth.uid())::text = provider_id
  );

CREATE POLICY "bookings_insert_self" ON public.bookings
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "bookings_update_own" ON public.bookings
  FOR UPDATE USING (
    (auth.uid())::text = user_id OR 
    (auth.uid())::text = provider_id
  );

-- =====================================================
-- SEAT_LAYOUTS TABLE
-- =====================================================
ALTER TABLE public.seat_layouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "seat_layouts_select_all" ON public.seat_layouts
  FOR SELECT USING (true);

CREATE POLICY "seat_layouts_insert_own" ON public.seat_layouts
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "seat_layouts_update_own" ON public.seat_layouts
  FOR UPDATE USING ((auth.uid())::text = user_id);

CREATE POLICY "seat_layouts_delete_own" ON public.seat_layouts
  FOR DELETE USING ((auth.uid())::text = user_id);

-- =====================================================
-- REVIEWS TABLE
-- =====================================================
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_select_all" ON public.reviews
  FOR SELECT USING (true);

CREATE POLICY "reviews_insert_own" ON public.reviews
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "reviews_update_own" ON public.reviews
  FOR UPDATE USING ((auth.uid())::text = user_id);

CREATE POLICY "reviews_delete_own" ON public.reviews
  FOR DELETE USING ((auth.uid())::text = user_id);

-- =====================================================
-- USER_POST_ACCEPTANCES TABLE
-- =====================================================
ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_post_acceptances_select" ON public.user_post_acceptances
  FOR SELECT USING (
    (auth.uid())::text = provider_id OR
    (auth.uid())::text = user_id
  );

CREATE POLICY "user_post_acceptances_insert" ON public.user_post_acceptances
  FOR INSERT WITH CHECK ((auth.uid())::text = provider_id);

CREATE POLICY "user_post_acceptances_update_provider" ON public.user_post_acceptances
  FOR UPDATE USING ((auth.uid())::text = provider_id);

CREATE POLICY "user_post_acceptances_delete" ON public.user_post_acceptances
  FOR DELETE USING ((auth.uid())::text = provider_id);

-- =====================================================
-- PROFILES TABLE (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
    
    EXECUTE 'CREATE POLICY "profiles_select_all" ON public.profiles FOR SELECT USING (true)';
    EXECUTE 'CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK ((auth.uid())::text = id)';
    EXECUTE 'CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING ((auth.uid())::text = id)';
    EXECUTE 'CREATE POLICY "profiles_delete_own" ON public.profiles FOR DELETE USING ((auth.uid())::text = id)';
  END IF;
END $$;

-- =====================================================
-- EVENTS TABLE (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events') THEN
    ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
    
    EXECUTE 'CREATE POLICY "events_select_all" ON public.events FOR SELECT USING (true)';
    EXECUTE 'CREATE POLICY "events_insert_own" ON public.events FOR INSERT WITH CHECK ((auth.uid())::text = user_id)';
    EXECUTE 'CREATE POLICY "events_update_own" ON public.events FOR UPDATE USING ((auth.uid())::text = user_id)';
    EXECUTE 'CREATE POLICY "events_delete_own" ON public.events FOR DELETE USING ((auth.uid())::text = user_id)';
  END IF;
END $$;

-- =====================================================
-- POSTS TABLE (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'posts') THEN
    ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
    
    EXECUTE 'CREATE POLICY "posts_select_all" ON public.posts FOR SELECT USING (true)';
    EXECUTE 'CREATE POLICY "posts_insert_own" ON public.posts FOR INSERT WITH CHECK ((auth.uid())::text = user_id)';
    EXECUTE 'CREATE POLICY "posts_update_own" ON public.posts FOR UPDATE USING ((auth.uid())::text = user_id)';
    EXECUTE 'CREATE POLICY "posts_delete_own" ON public.posts FOR DELETE USING ((auth.uid())::text = user_id)';
  END IF;
END $$;

COMMENT ON MIGRATION IS 'Restore RLS policies with TEXT user_id columns after UUID migration';
