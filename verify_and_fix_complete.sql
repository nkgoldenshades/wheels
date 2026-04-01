-- Complete verification and fix for Firebase Auth + Supabase integration
-- Run this in Supabase SQL Editor

-- =====================================================
-- STEP 1: Verify current column types
-- =====================================================
SELECT 
  table_name,
  column_name, 
  data_type,
  udt_name
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name IN ('users', 'vehicles', 'slots', 'bookings', 'reviews', 'seat_layouts')
  AND column_name IN ('id', 'user_id', 'provider_id')
ORDER BY table_name, column_name;

-- =====================================================
-- STEP 2: Check current RLS policies
-- =====================================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('users', 'vehicles', 'slots', 'bookings', 'reviews', 'seat_layouts')
ORDER BY tablename, policyname;

-- =====================================================
-- STEP 3: Test if auth.uid() works with Firebase JWT
-- =====================================================
-- This will show what auth.uid() returns when called with your Firebase token
-- Run this AFTER logging in with Firebase in your app
SELECT 
  auth.uid() as firebase_uid_from_jwt,
  pg_typeof(auth.uid()) as uid_type;

-- =====================================================
-- STEP 4: Fix any remaining UUID columns
-- =====================================================

-- Fix users table if needed
DO $$
BEGIN
  -- Check if users.id is UUID
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='users' AND column_name='id' AND data_type='uuid'
  ) THEN
    -- Disable RLS temporarily
    ALTER TABLE users DISABLE ROW LEVEL SECURITY;
    
    -- Drop all policies
    DROP POLICY IF EXISTS users_select_all ON users;
    DROP POLICY IF EXISTS users_insert_self ON users;
    DROP POLICY IF EXISTS users_update_self ON users;
    DROP POLICY IF EXISTS users_all_operations ON users;
    
    -- Convert to TEXT
    ALTER TABLE users ALTER COLUMN id TYPE text;
    
    -- Re-enable RLS
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    
    -- Recreate policy
    CREATE POLICY "users_all_operations" ON users
      FOR ALL USING (true) WITH CHECK (true);
      
    RAISE NOTICE 'Fixed users.id to TEXT';
  END IF;
END $$;

-- Fix bookings table if needed
DO $$
BEGIN
  -- Check if bookings columns are UUID
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='bookings' 
      AND column_name IN ('user_id', 'provider_id') 
      AND data_type='uuid'
  ) THEN
    -- Disable RLS temporarily
    ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
    
    -- Drop all policies
    DROP POLICY IF EXISTS bookings_select_own ON bookings;
    DROP POLICY IF EXISTS bookings_insert_self ON bookings;
    DROP POLICY IF EXISTS bookings_update_own ON bookings;
    DROP POLICY IF EXISTS bookings_all_operations ON bookings;
    DROP POLICY IF EXISTS insert_anon ON bookings;
    
    -- Drop foreign keys
    ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_user_id_fkey;
    ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_provider_id_fkey;
    
    -- Convert to TEXT
    ALTER TABLE bookings ALTER COLUMN user_id TYPE text;
    ALTER TABLE bookings ALTER COLUMN provider_id TYPE text;
    
    -- Recreate foreign keys
    ALTER TABLE bookings
      ADD CONSTRAINT bookings_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    ALTER TABLE bookings
      ADD CONSTRAINT bookings_provider_id_fkey 
        FOREIGN KEY (provider_id) REFERENCES users(id) ON DELETE CASCADE;
    
    -- Re-enable RLS with permissive policy
    ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY "bookings_all_operations" ON bookings
      FOR ALL USING (true) WITH CHECK (true);
      
    RAISE NOTICE 'Fixed bookings user_id and provider_id to TEXT';
  END IF;
END $$;

-- =====================================================
-- STEP 5: Verify the fix worked
-- =====================================================
SELECT 
  'bookings' as table_name,
  column_name, 
  data_type
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='bookings'
  AND column_name IN ('user_id', 'provider_id');

-- =====================================================
-- STEP 6: Test insert with Firebase UID format
-- =====================================================
-- This is a dry-run test - it will fail if types are wrong
-- Comment out if you don't want to test
/*
INSERT INTO bookings (
  id, user_id, provider_id, slot_id, price, status
) VALUES (
  'test_' || extract(epoch from now())::text,
  'GbsFkKmcHCQFJ0ceVoBWz2punch1',  -- Firebase UID format
  'GbsFkKmcHCQFJ0ceVoBWz2punch1',  -- Firebase UID format
  'test_slot_123',
  100,
  'pending'
) RETURNING id, user_id, provider_id;

-- Clean up test
DELETE FROM bookings WHERE id LIKE 'test_%';
*/
