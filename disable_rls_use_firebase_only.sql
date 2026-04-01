-- SIMPLEST FIX: Disable Supabase Auth/RLS entirely
-- Use Firebase for auth, Supabase as plain PostgreSQL database

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

-- User Post Acceptances table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_post_acceptances') THEN
    EXECUTE 'ALTER TABLE user_post_acceptances DROP CONSTRAINT IF EXISTS user_post_acceptances_user_id_fkey';
    EXECUTE 'ALTER TABLE user_post_acceptances DROP CONSTRAINT IF EXISTS user_post_acceptances_provider_id_fkey';
    EXECUTE 'ALTER TABLE user_post_acceptances ALTER COLUMN user_id TYPE text';
    EXECUTE 'ALTER TABLE user_post_acceptances ALTER COLUMN provider_id TYPE text';
    EXECUTE 'ALTER TABLE user_post_acceptances ADD CONSTRAINT user_post_acceptances_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE';
    EXECUTE 'ALTER TABLE user_post_acceptances ADD CONSTRAINT user_post_acceptances_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE';
  END IF;
END $$;

-- =====================================================
-- STEP 2: DISABLE RLS on all tables
-- =====================================================
-- Since Firebase handles authentication, we don't need Supabase RLS

ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE slots DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE seat_layouts DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_post_acceptances') THEN
    EXECUTE 'ALTER TABLE user_post_acceptances DISABLE ROW LEVEL SECURITY';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'posts') THEN
    EXECUTE 'ALTER TABLE posts DISABLE ROW LEVEL SECURITY';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events') THEN
    EXECUTE 'ALTER TABLE events DISABLE ROW LEVEL SECURITY';
  END IF;
END $$;

-- =====================================================
-- STEP 3: Verify changes
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

-- Check RLS status (should all be false)
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
  RAISE NOTICE '✅ RLS disabled on all tables';
  RAISE NOTICE '✅ Supabase is now a plain PostgreSQL database';
  RAISE NOTICE '✅ Firebase handles all authentication';
  RAISE NOTICE '✅ Your app can directly insert/update/query tables';
END $$;
