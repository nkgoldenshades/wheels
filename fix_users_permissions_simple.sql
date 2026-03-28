-- Simple fix for users table permissions
-- Run this in Supabase Dashboard > SQL Editor

-- First, drop ALL existing policies on users table
DROP POLICY IF EXISTS users_select_all ON public.users;
DROP POLICY IF EXISTS users_insert_self ON public.users;
DROP POLICY IF EXISTS users_insert_anon ON public.users;
DROP POLICY IF EXISTS users_insert_any ON public.users;
DROP POLICY IF EXISTS users_insert_all ON public.users;
DROP POLICY IF EXISTS users_update_self ON public.users;
DROP POLICY IF EXISTS users_update_any ON public.users;
DROP POLICY IF EXISTS users_update_all ON public.users;
DROP POLICY IF EXISTS users_delete_self ON public.users;
DROP POLICY IF EXISTS users_insert_self_auth ON public.users;
DROP POLICY IF EXISTS users_update_self_auth ON public.users;

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Create simple permissive policies
CREATE POLICY "users_select_all" ON public.users
  FOR SELECT 
  USING (true);

CREATE POLICY "users_insert_all" ON public.users
  FOR INSERT 
  WITH CHECK (true);

CREATE POLICY "users_update_all" ON public.users
  FOR UPDATE 
  USING (true)
  WITH CHECK (true);

CREATE POLICY "users_delete_own" ON public.users
  FOR DELETE 
  USING ((auth.uid())::text = id);

-- Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'users';
