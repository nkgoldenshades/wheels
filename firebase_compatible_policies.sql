-- Firebase-compatible RLS policies
-- Since Firebase handles auth, we make policies permissive
-- Run this in Supabase Dashboard > SQL Editor

-- =====================================================
-- USERS TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS users_select_all ON public.users;
DROP POLICY IF EXISTS users_insert_all ON public.users;
DROP POLICY IF EXISTS users_update_all ON public.users;
DROP POLICY IF EXISTS users_delete_own ON public.users;
DROP POLICY IF EXISTS users_select_all_auth ON public.users;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_all_operations" ON public.users
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- VEHICLES TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS vehicles_select_all ON public.vehicles;
DROP POLICY IF EXISTS vehicles_insert_self ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_self ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_self ON public.vehicles;

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vehicles_all_operations" ON public.vehicles
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- SLOTS TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS slots_select_all ON public.slots;
DROP POLICY IF EXISTS slots_insert_self ON public.slots;
DROP POLICY IF EXISTS slots_update_self ON public.slots;
DROP POLICY IF EXISTS slots_delete_self ON public.slots;

ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "slots_all_operations" ON public.slots
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- BOOKINGS TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS bookings_select_own ON public.bookings;
DROP POLICY IF EXISTS bookings_insert_self ON public.bookings;
DROP POLICY IF EXISTS bookings_update_own ON public.bookings;

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookings_all_operations" ON public.bookings
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- SEAT_LAYOUTS TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS seat_layouts_select_all ON public.seat_layouts;
DROP POLICY IF EXISTS seat_layouts_insert_own ON public.seat_layouts;
DROP POLICY IF EXISTS seat_layouts_update_own ON public.seat_layouts;
DROP POLICY IF EXISTS seat_layouts_delete_own ON public.seat_layouts;

ALTER TABLE public.seat_layouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "seat_layouts_all_operations" ON public.seat_layouts
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- REVIEWS TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS reviews_select_all ON public.reviews;
DROP POLICY IF EXISTS reviews_insert_own ON public.reviews;
DROP POLICY IF EXISTS reviews_update_own ON public.reviews;
DROP POLICY IF EXISTS reviews_delete_own ON public.reviews;

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_all_operations" ON public.reviews
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- USER_POST_ACCEPTANCES TABLE - Allow all operations
-- =====================================================
DROP POLICY IF EXISTS user_post_acceptances_select ON public.user_post_acceptances;
DROP POLICY IF EXISTS user_post_acceptances_insert ON public.user_post_acceptances;
DROP POLICY IF EXISTS user_post_acceptances_update_provider ON public.user_post_acceptances;
DROP POLICY IF EXISTS user_post_acceptances_delete ON public.user_post_acceptances;

ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_post_acceptances_all_operations" ON public.user_post_acceptances
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- POSTS TABLE - Allow all operations (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'posts') THEN
    EXECUTE 'DROP POLICY IF EXISTS posts_select_all ON public.posts';
    EXECUTE 'DROP POLICY IF EXISTS posts_insert_own ON public.posts';
    EXECUTE 'DROP POLICY IF EXISTS posts_update_own ON public.posts';
    EXECUTE 'DROP POLICY IF EXISTS posts_delete_own ON public.posts';
    
    EXECUTE 'ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY';
    
    EXECUTE 'CREATE POLICY "posts_all_operations" ON public.posts FOR ALL USING (true) WITH CHECK (true)';
  END IF;
END $$;

-- =====================================================
-- EVENTS TABLE - Allow all operations (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events') THEN
    EXECUTE 'DROP POLICY IF EXISTS events_select_all ON public.events';
    EXECUTE 'DROP POLICY IF EXISTS events_insert_own ON public.events';
    EXECUTE 'DROP POLICY IF EXISTS events_update_own ON public.events';
    EXECUTE 'DROP POLICY IF EXISTS events_delete_own ON public.events';
    
    EXECUTE 'ALTER TABLE public.events ENABLE ROW LEVEL SECURITY';
    
    EXECUTE 'CREATE POLICY "events_all_operations" ON public.events FOR ALL USING (true) WITH CHECK (true)';
  END IF;
END $$;

-- =====================================================
-- PROFILES TABLE - Allow all operations (if exists)
-- =====================================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    EXECUTE 'DROP POLICY IF EXISTS profiles_select_all ON public.profiles';
    EXECUTE 'DROP POLICY IF EXISTS profiles_insert_own ON public.profiles';
    EXECUTE 'DROP POLICY IF EXISTS profiles_update_own ON public.profiles';
    EXECUTE 'DROP POLICY IF EXISTS profiles_delete_own ON public.profiles';
    
    EXECUTE 'ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY';
    
    EXECUTE 'CREATE POLICY "profiles_all_operations" ON public.profiles FOR ALL USING (true) WITH CHECK (true)';
  END IF;
END $$;

-- Verify all policies
SELECT schemaname, tablename, policyname, permissive, cmd 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
