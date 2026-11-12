-- Nuclear option: Disable RLS on users table
-- Since Firebase handles authentication, we don't need Supabase RLS on users
-- Run this in Supabase Dashboard > SQL Editor

-- Disable RLS on users table
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT 
  relrowsecurity as rls_enabled, 
  relforcerowsecurity as rls_forced 
FROM pg_class 
WHERE relname = 'users';

-- This should show: rls_enabled = false, rls_forced = false
