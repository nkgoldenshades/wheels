-- Diagnostic queries to check users table RLS configuration
-- Run this in Supabase Dashboard > SQL Editor

-- Query 1: Check all policies on users table
SELECT 
  policyname, 
  cmd, 
  roles, 
  qual, 
  with_check 
FROM pg_policies 
WHERE tablename = 'users' 
ORDER BY policyname;

-- Query 2: Check if RLS is enabled on users table
SELECT 
  relrowsecurity as rls_enabled, 
  relforcerowsecurity as rls_forced 
FROM pg_class 
WHERE relname = 'users';

-- Query 3: Check users table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;
