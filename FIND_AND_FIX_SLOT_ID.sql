-- ============================================
-- COMPREHENSIVE FIX: Find and Fix ALL slot_id References
-- ============================================
-- Run this in Supabase SQL Editor to fix vehicle deletion errors
-- This script will find and fix ALL slot_id references in your database

-- ============================================
-- STEP 1: DIAGNOSTIC - Find ALL slot_id References
-- ============================================

-- 1.1 Find in RLS Policies
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 SEARCHING FOR slot_id IN RLS POLICIES';
  RAISE NOTICE '========================================';
  
  FOR policy_record IN 
    SELECT 
      schemaname,
      tablename,
      policyname,
      qual::text as using_clause,
      with_check::text as with_check_clause
    FROM pg_policies 
    WHERE qual::text ILIKE '%slot_id%' 
       OR with_check::text ILIKE '%slot_id%'
  LOOP
    RAISE NOTICE '❌ FOUND: %.% policy "%"', 
      policy_record.schemaname, 
      policy_record.tablename, 
      policy_record.policyname;
    RAISE NOTICE '   USING: %', policy_record.using_clause;
    RAISE NOTICE '   WITH CHECK: %', policy_record.with_check_clause;
  END LOOP;
END $$;

-- 1.2 Find in Functions
DO $$
DECLARE
  func_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 SEARCHING FOR slot_id IN FUNCTIONS';
  RAISE NOTICE '========================================';
  
  FOR func_record IN 
    SELECT 
      routine_name,
      routine_definition
    FROM information_schema.routines 
    WHERE routine_definition ILIKE '%slot_id%'
      AND routine_schema = 'public'
  LOOP
    RAISE NOTICE '❌ FOUND: Function "%"', func_record.routine_name;
    RAISE NOTICE '   Definition contains: slot_id';
  END LOOP;
END $$;

-- 1.3 Find in Triggers
DO $$
DECLARE
  trigger_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 SEARCHING FOR slot_id IN TRIGGERS';
  RAISE NOTICE '========================================';
  
  FOR trigger_record IN 
    SELECT 
      trigger_name,
      event_object_table,
      action_statement
    FROM information_schema.triggers
    WHERE action_statement ILIKE '%slot_id%'
  LOOP
    RAISE NOTICE '❌ FOUND: Trigger "%" on table "%"', 
      trigger_record.trigger_name,
      trigger_record.event_object_table;
  END LOOP;
END $$;

-- 1.4 Find in Foreign Keys
DO $$
DECLARE
  fk_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 SEARCHING FOR slot_id IN FOREIGN KEYS';
  RAISE NOTICE '========================================';
  
  FOR fk_record IN 
    SELECT
      tc.table_name,
      tc.constraint_name,
      kcu.column_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND (kcu.column_name = 'slot_id' OR ccu.column_name = 'slot_id')
  LOOP
    RAISE NOTICE '❌ FOUND: %.% (%) -> %.%', 
      fk_record.table_name,
      fk_record.column_name,
      fk_record.constraint_name,
      fk_record.foreign_table_name,
      fk_record.foreign_column_name;
  END LOOP;
END $$;

-- 1.5 Check bookings table structure
DO $$
DECLARE
  col_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 BOOKINGS TABLE STRUCTURE';
  RAISE NOTICE '========================================';
  
  FOR col_record IN 
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'bookings'
      AND table_schema = 'public'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '  • % (%) %', 
      col_record.column_name,
      col_record.data_type,
      CASE WHEN col_record.is_nullable = 'YES' THEN 'NULL' ELSE 'NOT NULL' END;
  END LOOP;
END $$;

-- ============================================
-- STEP 2: FIX - Drop ALL RLS Policies with slot_id
-- ============================================

DO $$
DECLARE
  policy_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 DROPPING RLS POLICIES WITH slot_id';
  RAISE NOTICE '========================================';
  
  FOR policy_record IN 
    SELECT 
      schemaname,
      tablename,
      policyname
    FROM pg_policies 
    WHERE qual::text ILIKE '%slot_id%' 
       OR with_check::text ILIKE '%slot_id%'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename);
    RAISE NOTICE '✅ Dropped policy "%" on %.%', 
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename;
  END LOOP;
END $$;

-- ============================================
-- STEP 3: FIX - Create NEW RLS Policies with post_id
-- ============================================

-- Drop ALL existing bookings policies first (clean slate)
DROP POLICY IF EXISTS "bookings_select_own" ON bookings;
DROP POLICY IF EXISTS "bookings_insert_user" ON bookings;
DROP POLICY IF EXISTS "bookings_update_provider" ON bookings;
DROP POLICY IF EXISTS "Users can view own bookings as customer" ON bookings;
DROP POLICY IF EXISTS "Users can view own bookings as provider" ON bookings;
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;
DROP POLICY IF EXISTS "Providers can update bookings" ON bookings;
DROP POLICY IF EXISTS "bookings_select_customer" ON bookings;
DROP POLICY IF EXISTS "bookings_select_provider" ON bookings;
DROP POLICY IF EXISTS "bookings_insert" ON bookings;
DROP POLICY IF EXISTS "bookings_update" ON bookings;

-- Create SIMPLE, CORRECT policies using post_id
CREATE POLICY "bookings_select_as_customer" ON bookings
  FOR SELECT
  USING (profile_customer_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_select_as_provider" ON bookings
  FOR SELECT
  USING (profile_provider_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_insert_as_customer" ON bookings
  FOR INSERT
  WITH CHECK (profile_customer_id = (auth.jwt() ->> 'sub'::text));

CREATE POLICY "bookings_update_by_owner" ON bookings
  FOR UPDATE
  USING (
    profile_provider_id = (auth.jwt() ->> 'sub'::text) 
    OR profile_customer_id = (auth.jwt() ->> 'sub'::text)
  );

RAISE NOTICE '✅ Created new RLS policies for bookings using post_id';

-- ============================================
-- STEP 4: FIX - Foreign Key Constraints
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 FIXING FOREIGN KEY CONSTRAINTS';
  RAISE NOTICE '========================================';
  
  -- Drop old slot_id constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bookings_slot_id_fkey' 
    AND table_name = 'bookings'
  ) THEN
    ALTER TABLE bookings DROP CONSTRAINT bookings_slot_id_fkey;
    RAISE NOTICE '✅ Dropped old bookings_slot_id_fkey constraint';
  ELSE
    RAISE NOTICE '⚠️  No bookings_slot_id_fkey constraint found (already removed)';
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
    RAISE NOTICE '✅ Added new bookings_post_id_fkey constraint';
  ELSE
    RAISE NOTICE '✅ bookings_post_id_fkey constraint already exists';
  END IF;
END $$;

-- ============================================
-- STEP 5: FIX - Indexes
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 FIXING INDEXES';
  RAISE NOTICE '========================================';
END $$;

-- Drop old slot_id indexes
DROP INDEX IF EXISTS idx_bookings_slot_id;
DROP INDEX IF EXISTS idx_bookings_slot;

-- Create new post_id index
CREATE INDEX IF NOT EXISTS idx_bookings_post_id ON bookings(post_id);

RAISE NOTICE '✅ Indexes updated';

-- ============================================
-- STEP 6: VERIFY - Check Everything is Fixed
-- ============================================

DO $$
DECLARE
  policy_count INTEGER;
  func_count INTEGER;
  trigger_count INTEGER;
  fk_count INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ VERIFICATION - Checking for Remaining slot_id References';
  RAISE NOTICE '========================================';
  
  -- Check RLS policies
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies 
  WHERE qual::text ILIKE '%slot_id%' 
     OR with_check::text ILIKE '%slot_id%';
  
  IF policy_count > 0 THEN
    RAISE WARNING '⚠️  Still found % RLS policies with slot_id', policy_count;
  ELSE
    RAISE NOTICE '✅ No RLS policies with slot_id found';
  END IF;
  
  -- Check functions
  SELECT COUNT(*) INTO func_count
  FROM information_schema.routines 
  WHERE routine_definition ILIKE '%slot_id%'
    AND routine_schema = 'public';
  
  IF func_count > 0 THEN
    RAISE WARNING '⚠️  Still found % functions with slot_id', func_count;
  ELSE
    RAISE NOTICE '✅ No functions with slot_id found';
  END IF;
  
  -- Check triggers
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE action_statement ILIKE '%slot_id%';
  
  IF trigger_count > 0 THEN
    RAISE WARNING '⚠️  Still found % triggers with slot_id', trigger_count;
  ELSE
    RAISE NOTICE '✅ No triggers with slot_id found';
  END IF;
  
  -- Check foreign keys
  SELECT COUNT(*) INTO fk_count
  FROM information_schema.table_constraints AS tc
  JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'slot_id';
  
  IF fk_count > 0 THEN
    RAISE WARNING '⚠️  Still found % foreign keys with slot_id', fk_count;
  ELSE
    RAISE NOTICE '✅ No foreign keys with slot_id found';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  IF policy_count = 0 AND func_count = 0 AND trigger_count = 0 AND fk_count = 0 THEN
    RAISE NOTICE '🎉 SUCCESS! All slot_id references have been fixed!';
    RAISE NOTICE '🎉 You can now delete vehicles without errors!';
  ELSE
    RAISE WARNING '⚠️  Some slot_id references still remain - check output above';
  END IF;
  RAISE NOTICE '========================================';
END $$;

-- ============================================
-- STEP 7: Show Current Bookings RLS Policies
-- ============================================

DO $$
DECLARE
  policy_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📋 CURRENT BOOKINGS RLS POLICIES';
  RAISE NOTICE '========================================';
  
  FOR policy_record IN 
    SELECT 
      policyname,
      cmd,
      qual::text as using_clause,
      with_check::text as with_check_clause
    FROM pg_policies 
    WHERE tablename = 'bookings'
    ORDER BY policyname
  LOOP
    RAISE NOTICE '';
    RAISE NOTICE 'Policy: % (FOR %)', policy_record.policyname, policy_record.cmd;
    RAISE NOTICE '  USING: %', COALESCE(policy_record.using_clause, '(none)');
    RAISE NOTICE '  WITH CHECK: %', COALESCE(policy_record.with_check_clause, '(none)');
  END LOOP;
END $$;
