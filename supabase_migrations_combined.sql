-- =====================================================
-- COMBINED MIGRATIONS FOR SUPABASE DASHBOARD
-- Run this in Supabase Dashboard > SQL Editor
-- =====================================================

-- =====================================================
-- MIGRATION 007: Fix user_id columns to accept Firebase Auth string IDs
-- =====================================================

-- 1. Drop views that depend on users.id
DROP VIEW IF EXISTS public_profiles CASCADE;

-- 2. Fix users table
ALTER TABLE users ALTER COLUMN id TYPE TEXT;

-- 3. Recreate public_profiles view
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
  id,
  email,
  created_at,
  updated_at
FROM users;

GRANT SELECT ON public_profiles TO authenticated;
GRANT SELECT ON public_profiles TO anon;

-- 4. Fix vehicles table
ALTER TABLE vehicles ALTER COLUMN user_id TYPE TEXT;

-- 5. Fix posts table (if exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'posts') THEN
    ALTER TABLE posts ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE posts ALTER COLUMN provider_id TYPE TEXT;
  END IF;
END $$;

-- 6. Fix slots table
ALTER TABLE slots ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE slots ALTER COLUMN provider_id TYPE TEXT;

-- 7. Fix bookings table
ALTER TABLE bookings ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE bookings ALTER COLUMN provider_id TYPE TEXT;

-- 8. Fix user_post_acceptances table
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_post_acceptances') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'user_post_acceptances' AND column_name = 'user_id'
    ) THEN
      ALTER TABLE user_post_acceptances ADD COLUMN user_id TEXT;
    ELSE
      ALTER TABLE user_post_acceptances ALTER COLUMN user_id TYPE TEXT;
    END IF;
  END IF;
END $$;

-- 9. Fix reviews table
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reviews') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'user_id') THEN
      ALTER TABLE reviews ALTER COLUMN user_id TYPE TEXT;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'provider_id') THEN
      ALTER TABLE reviews ALTER COLUMN provider_id TYPE TEXT;
    END IF;
  END IF;
END $$;

-- 10. Fix events table
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'user_id') THEN
      ALTER TABLE events ALTER COLUMN user_id TYPE TEXT;
    END IF;
  END IF;
END $$;

-- =====================================================
-- MIGRATION 008: Restore RLS policies
-- =====================================================

-- USERS TABLE
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_all ON public.users;
CREATE POLICY "users_select_all" ON public.users
  FOR SELECT USING (true);

DROP POLICY IF EXISTS users_insert_self ON public.users;
CREATE POLICY "users_insert_self" ON public.users
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS users_update_self ON public.users;
CREATE POLICY "users_update_self" ON public.users
  FOR UPDATE USING ((auth.uid())::text = id);

-- VEHICLES TABLE
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vehicles_select_all ON public.vehicles;
CREATE POLICY "vehicles_select_all" ON public.vehicles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS vehicles_insert_self ON public.vehicles;
CREATE POLICY "vehicles_insert_self" ON public.vehicles
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS vehicles_update_self ON public.vehicles;
CREATE POLICY "vehicles_update_self" ON public.vehicles
  FOR UPDATE USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS vehicles_delete_self ON public.vehicles;
CREATE POLICY "vehicles_delete_self" ON public.vehicles
  FOR DELETE USING ((auth.uid())::text = user_id);

-- SLOTS TABLE
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS slots_select_all ON public.slots;
CREATE POLICY "slots_select_all" ON public.slots
  FOR SELECT USING (true);

DROP POLICY IF EXISTS slots_insert_self ON public.slots;
CREATE POLICY "slots_insert_self" ON public.slots
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS slots_update_self ON public.slots;
CREATE POLICY "slots_update_self" ON public.slots
  FOR UPDATE USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS slots_delete_self ON public.slots;
CREATE POLICY "slots_delete_self" ON public.slots
  FOR DELETE USING ((auth.uid())::text = user_id);

-- BOOKINGS TABLE
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bookings_select_own ON public.bookings;
CREATE POLICY "bookings_select_own" ON public.bookings
  FOR SELECT USING (
    (auth.uid())::text = user_id OR 
    (auth.uid())::text = provider_id
  );

DROP POLICY IF EXISTS bookings_insert_self ON public.bookings;
CREATE POLICY "bookings_insert_self" ON public.bookings
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS bookings_update_own ON public.bookings;
CREATE POLICY "bookings_update_own" ON public.bookings
  FOR UPDATE USING (
    (auth.uid())::text = user_id OR 
    (auth.uid())::text = provider_id
  );

-- SEAT_LAYOUTS TABLE
ALTER TABLE public.seat_layouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS seat_layouts_select_all ON public.seat_layouts;
CREATE POLICY "seat_layouts_select_all" ON public.seat_layouts
  FOR SELECT USING (true);

DROP POLICY IF EXISTS seat_layouts_insert_own ON public.seat_layouts;
CREATE POLICY "seat_layouts_insert_own" ON public.seat_layouts
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS seat_layouts_update_own ON public.seat_layouts;
CREATE POLICY "seat_layouts_update_own" ON public.seat_layouts
  FOR UPDATE USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS seat_layouts_delete_own ON public.seat_layouts;
CREATE POLICY "seat_layouts_delete_own" ON public.seat_layouts
  FOR DELETE USING ((auth.uid())::text = user_id);

-- REVIEWS TABLE
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reviews_select_all ON public.reviews;
CREATE POLICY "reviews_select_all" ON public.reviews
  FOR SELECT USING (true);

DROP POLICY IF EXISTS reviews_insert_own ON public.reviews;
CREATE POLICY "reviews_insert_own" ON public.reviews
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS reviews_update_own ON public.reviews;
CREATE POLICY "reviews_update_own" ON public.reviews
  FOR UPDATE USING ((auth.uid())::text = user_id);

DROP POLICY IF EXISTS reviews_delete_own ON public.reviews;
CREATE POLICY "reviews_delete_own" ON public.reviews
  FOR DELETE USING ((auth.uid())::text = user_id);

-- USER_POST_ACCEPTANCES TABLE
ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_post_acceptances_select ON public.user_post_acceptances;
CREATE POLICY "user_post_acceptances_select" ON public.user_post_acceptances
  FOR SELECT USING (
    (auth.uid())::text = provider_id OR
    (auth.uid())::text = user_id
  );

DROP POLICY IF EXISTS user_post_acceptances_insert ON public.user_post_acceptances;
CREATE POLICY "user_post_acceptances_insert" ON public.user_post_acceptances
  FOR INSERT WITH CHECK ((auth.uid())::text = provider_id);

DROP POLICY IF EXISTS user_post_acceptances_update_provider ON public.user_post_acceptances;
CREATE POLICY "user_post_acceptances_update_provider" ON public.user_post_acceptances
  FOR UPDATE USING ((auth.uid())::text = provider_id);

DROP POLICY IF EXISTS user_post_acceptances_delete ON public.user_post_acceptances;
CREATE POLICY "user_post_acceptances_delete" ON public.user_post_acceptances
  FOR DELETE USING ((auth.uid())::text = provider_id);

-- =====================================================
-- MIGRATION 009: Add missing columns and fix permissions
-- =====================================================

-- Add missing columns to vehicles table
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS is_user_vehicle BOOLEAN DEFAULT false;

-- =====================================================
-- MIGRATION 010: Fix users table permissions for Firebase Auth
-- =====================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS users_insert_self ON public.users;
DROP POLICY IF EXISTS users_insert_anon ON public.users;
DROP POLICY IF EXISTS users_insert_any ON public.users;
DROP POLICY IF EXISTS users_update_self ON public.users;
DROP POLICY IF EXISTS users_update_any ON public.users;

-- Allow anyone to insert users (for Firebase Auth sync)
CREATE POLICY users_insert_all ON public.users
  FOR INSERT 
  WITH CHECK (true);

-- Allow anyone to update users (for profile updates)
CREATE POLICY users_update_all ON public.users
  FOR UPDATE 
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- DONE! Your database is now ready for Firebase Auth
-- =====================================================
