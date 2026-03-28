-- Fix users table permissions to allow inserts and updates

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

-- Keep select policy as is
-- users_select_all should already exist

COMMENT ON MIGRATION IS 'Allow Firebase Auth to sync users to Supabase without permission errors';
