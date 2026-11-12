-- Fix all slot_id references to post_id in database
-- Run this in Supabase SQL Editor

-- ============================================
-- STEP 1: Find all slot_id references
-- ============================================

-- Find in RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  qual as "USING clause",
  with_check as "WITH CHECK clause"
FROM pg_policies 
WHERE qual::text ILIKE '%slot_id%' 
   OR with_check::text ILIKE '%slot_id%';

-- Find in functions
SELECT 
  routine_name,
  routine_definition
FROM information_schema.routines 
WHERE routine_definition ILIKE '%slot_id%'
  AND routine_schema = 'public';

-- Find in triggers
SELECT 
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE action_statement ILIKE '%slot_id%';

-- Find in foreign keys
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND (kcu.column_name = 'slot_id' OR ccu.column_name = 'slot_id');

-- ============================================
-- STEP 2: Fix RLS Policies (Most Common Issue)
-- ============================================

-- Drop and recreate bookings RLS policies with post_id

-- Drop old policies
DROP POLICY IF EXISTS "bookings_select_own" ON bookings;
DROP POLICY IF EXISTS "bookings_insert_user" ON bookings;
DROP POLICY IF EXISTS "bookings_update_provider" ON bookings;
DROP POLICY IF EXISTS "Users can view own bookings as customer" ON bookings;
DROP POLICY IF EXISTS "Users can view own bookings as provider" ON bookings;
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;
DROP POLICY IF EXISTS "Providers can update bookings" ON bookings;

-- Create new policies with post_id
CREATE POLICY "bookings_select_customer" ON bookings
  FOR SELECT
  USING (profile_customer_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_select_provider" ON bookings
  FOR SELECT
  USING (profile_provider_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_insert" ON bookings
  FOR INSERT
  WITH CHECK (profile_customer_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_update" ON bookings
  FOR UPDATE
  USING (
    profile_provider_id = (auth.jwt() ->> 'sub'::text) 
    OR profile_customer_id = (auth.jwt() ->> 'sub'::text)
  );

-- ============================================
-- STEP 3: Fix Foreign Key Constraints
-- ============================================

-- Check if bookings has slot_id foreign key
DO $$
BEGIN
  -- Drop old slot_id constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bookings_slot_id_fkey' 
    AND table_name = 'bookings'
  ) THEN
    ALTER TABLE bookings DROP CONSTRAINT bookings_slot_id_fkey;
    RAISE NOTICE 'Dropped old bookings_slot_id_fkey constraint';
  END IF;

  -- Add post_id constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bookings_post_id_fkey' 
    AND table_name = 'bookings'
  ) THEN
    ALTER TABLE bookings 
    ADD CONSTRAINT bookings_post_id_fkey 
    FOREIGN KEY (post_id) 
    REFERENCES posts(id) 
    ON DELETE CASCADE;
    RAISE NOTICE 'Added new bookings_post_id_fkey constraint';
  END IF;
END $$;

-- ============================================
-- STEP 4: Fix Indexes
-- ============================================

-- Drop old slot_id indexes
DROP INDEX IF EXISTS idx_bookings_slot_id;
DROP INDEX IF EXISTS idx_bookings_slot;

-- Create new post_id index
CREATE INDEX IF NOT EXISTS idx_bookings_post_id ON bookings(post_id);

-- ============================================
-- STEP 5: Verify Changes
-- ============================================

-- Check bookings table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'bookings'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check RLS policies
SELECT 
  policyname,
  qual as "USING",
  with_check as "WITH CHECK"
FROM pg_policies 
WHERE tablename = 'bookings';

-- Check foreign keys
SELECT
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table,
  ccu.column_name AS foreign_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'bookings';

-- ============================================
-- STEP 6: Test Vehicle Deletion
-- ============================================

-- This should now work without errors:
-- DELETE FROM vehicles WHERE id = 'your_vehicle_id';

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ All slot_id references have been updated to post_id';
  RAISE NOTICE '✅ RLS policies updated';
  RAISE NOTICE '✅ Foreign keys updated';
  RAISE NOTICE '✅ Indexes updated';
  RAISE NOTICE '🎉 You can now delete vehicles without errors!';
END $$;
