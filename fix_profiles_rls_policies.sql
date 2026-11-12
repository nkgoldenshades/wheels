-- Fix RLS policies for profiles table
-- Run this in Supabase SQL Editor

-- Enable RLS on profiles table (if not already enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;

-- Policy 1: Users can view their own profile
CREATE POLICY "Users can view own profile" 
ON public.profiles
FOR SELECT 
USING (id = auth.jwt()->>'sub');

-- Policy 2: Users can insert their own profile (for signup)
CREATE POLICY "Users can insert own profile" 
ON public.profiles
FOR INSERT 
WITH CHECK (id = auth.jwt()->>'sub');

-- Policy 3: Users can update their own profile
CREATE POLICY "Users can update own profile" 
ON public.profiles
FOR UPDATE 
USING (id = auth.jwt()->>'sub')
WITH CHECK (id = auth.jwt()->>'sub');

-- Policy 4: All authenticated users can view other profiles (for public info like name, avatar)
-- This is needed for showing provider/customer info in bookings
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles
FOR SELECT 
TO authenticated
USING (true);

-- Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;
