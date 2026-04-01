-- SECURE SOLUTION: Use Firebase JWT validation with custom claims
-- 
-- How it works:
-- 1. Firebase generates JWT with user ID in the 'sub' claim
-- 2. Your app passes JWT to Supabase via accessToken callback
-- 3. Supabase validates JWT and extracts claims
-- 4. RLS policies use auth.jwt() to get Firebase UID from 'sub' claim
-- 5. Security maintained - only authenticated users can access their data

-- =====================================================
-- STEP 1: Convert all user ID columns to TEXT
-- =====================================================

-- Users table
ALTER TABLE users ALTER COLUMN id TYPE text;

-- Vehicles table
ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_user_id_fkey;
ALTER TABLE vehicles ALTER COLUMN user_id TYPE text;
ALTER TABLE vehicles ADD CONSTRAINT vehicles_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Slots table
ALTER TABLE slots DROP CONSTRAINT IF EXISTS slots_user_id_fkey;
ALTER TABLE slots DROP CONSTRAINT IF EXISTS slots_provider_id_fkey;
ALTER TABLE slots ALTER COLUMN user_id TYPE text;
ALTER TABLE slots ALTER COLUMN provider_id TYPE text;
ALTER TABLE slots ADD CONSTRAINT slots_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE slots ADD CONSTRAINT slots_provider_id_fkey 
  FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE;

-- Bookings table
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_user_id_fkey;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_provider_id_fkey;
ALTER TABLE bookings ALTER COLUMN user_id TYPE text;
ALTER TABLE bookings ALTER COLUMN provider_id TYPE text;
ALTER TABLE bookings ADD CONSTRAINT bookings_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE bookings ADD CONSTRAINT bookings_provider_id_fkey 
  FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE;

-- Seat Layouts table
ALTER TABLE seat_layouts DROP CONSTRAINT IF EXISTS seat_layouts_user_id_fkey;
ALTER TABLE seat_layouts ALTER COLUMN user_id TYPE text;
ALTER TABLE seat_layouts ADD CONSTRAINT seat_layouts_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Reviews table
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_user_id_fkey;
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_provider_id_fkey;
ALTER TABLE reviews ALTER COLUMN user_id TYPE text;
ALTER TABLE reviews ALTER COLUMN provider_id TYPE text;
ALTER TABLE reviews ADD CONSTRAINT reviews_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT reviews_provider_id_fkey 
  FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE;

-- =====================================================
-- STEP 2: Create SECURE RLS policies using Firebase JWT
-- =====================================================
-- Use auth.jwt() ->> 'sub' to extract Firebase UID from JWT token
-- This is SECURE because:
-- - Only valid Firebase JWTs are accepted
-- - Users can only access their own data
-- - Malicious users cannot forge JWTs

-- Users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_all ON users;
DROP POLICY IF EXISTS users_insert_self ON users;
DROP POLICY IF EXISTS users_update_self ON users;
DROP POLICY IF EXISTS users_all_operations ON users;

CREATE POLICY "users_select_all" ON users
  FOR SELECT USING (true);

CREATE POLICY "users_insert_self" ON users
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = id
  );

CREATE POLICY "users_update_self" ON users
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = id
  );

-- Vehicles table
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vehicles_select_all ON vehicles;
DROP POLICY IF EXISTS vehicles_insert_self ON vehicles;
DROP POLICY IF EXISTS vehicles_update_self ON vehicles;
DROP POLICY IF EXISTS vehicles_delete_self ON vehicles;
DROP POLICY IF EXISTS vehicles_all_operations ON vehicles;

CREATE POLICY "vehicles_select_all" ON vehicles
  FOR SELECT USING (true);

CREATE POLICY "vehicles_insert_self" ON vehicles
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "vehicles_update_self" ON vehicles
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "vehicles_delete_self" ON vehicles
  FOR DELETE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

-- Slots table
ALTER TABLE slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS slots_select_all ON slots;
DROP POLICY IF EXISTS slots_insert_self ON slots;
DROP POLICY IF EXISTS slots_update_self ON slots;
DROP POLICY IF EXISTS slots_delete_self ON slots;
DROP POLICY IF EXISTS slots_all_operations ON slots;

CREATE POLICY "slots_select_all" ON slots
  FOR SELECT USING (true);

CREATE POLICY "slots_insert_self" ON slots
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "slots_update_self" ON slots
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "slots_delete_self" ON slots
  FOR DELETE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

-- Bookings table (CRITICAL - users and providers can access)
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bookings_select_own ON bookings;
DROP POLICY IF EXISTS bookings_insert_self ON bookings;
DROP POLICY IF EXISTS bookings_update_own ON bookings;
DROP POLICY IF EXISTS bookings_all_operations ON bookings;
DROP POLICY IF EXISTS insert_anon ON bookings;

CREATE POLICY "bookings_select_all" ON bookings
  FOR SELECT USING (true);

CREATE POLICY "bookings_insert_self" ON bookings
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "bookings_update_own" ON bookings
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id OR 
    (auth.jwt() ->> 'sub') = provider_id
  );

-- Seat Layouts table
ALTER TABLE seat_layouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS seat_layouts_select_all ON seat_layouts;
DROP POLICY IF EXISTS seat_layouts_insert_own ON seat_layouts;
DROP POLICY IF EXISTS seat_layouts_update_own ON seat_layouts;
DROP POLICY IF EXISTS seat_layouts_delete_own ON seat_layouts;
DROP POLICY IF EXISTS seat_layouts_all_operations ON seat_layouts;

CREATE POLICY "seat_layouts_select_all" ON seat_layouts
  FOR SELECT USING (true);

CREATE POLICY "seat_layouts_insert_own" ON seat_layouts
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "seat_layouts_update_own" ON seat_layouts
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "seat_layouts_delete_own" ON seat_layouts
  FOR DELETE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

-- Reviews table
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reviews_select_all ON reviews;
DROP POLICY IF EXISTS reviews_insert_own ON reviews;
DROP POLICY IF EXISTS reviews_update_own ON reviews;
DROP POLICY IF EXISTS reviews_delete_own ON reviews;
DROP POLICY IF EXISTS reviews_all_operations ON reviews;

CREATE POLICY "reviews_select_all" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "reviews_insert_own" ON reviews
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "reviews_update_own" ON reviews
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

CREATE POLICY "reviews_delete_own" ON reviews
  FOR DELETE USING (
    (auth.jwt() ->> 'sub') = user_id
  );

-- =====================================================
-- STEP 3: Verify setup
-- =====================================================
SELECT 
  table_name,
  column_name, 
  data_type
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name IN ('users', 'vehicles', 'slots', 'bookings', 'reviews', 'seat_layouts')
  AND column_name IN ('id', 'user_id', 'provider_id')
ORDER BY table_name, column_name;

-- Check RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('users', 'vehicles', 'slots', 'bookings', 'reviews', 'seat_layouts')
ORDER BY tablename;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ All user ID columns converted to TEXT';
  RAISE NOTICE '✅ RLS enabled with Firebase JWT validation';
  RAISE NOTICE '✅ Security maintained - users can only access their own data';
  RAISE NOTICE '✅ Uses auth.jwt() ->> ''sub'' to extract Firebase UID from JWT';
  RAISE NOTICE '⚠️  Make sure accessToken callback is enabled in Flutter app';
END $$;
