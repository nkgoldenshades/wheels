-- ============================================================================
-- COMPLETE RLS FIX FOR ALL TABLES
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

-- Step 1: Temporarily disable RLS on profiles to allow initial setup
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies on profiles
DO $$ 
BEGIN
    EXECUTE (
        SELECT string_agg('DROP POLICY IF EXISTS ' || quote_ident(policyname) || ' ON public.profiles;', ' ')
        FROM pg_policies 
        WHERE tablename = 'profiles'
    );
END $$;

-- Step 3: Re-enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Step 4: Create proper policies for Firebase JWT
-- These policies extract the 'sub' claim from Firebase JWT which contains the user ID

-- Allow users to INSERT their own profile (for signup)
CREATE POLICY "users_insert_own_profile" 
ON public.profiles 
FOR INSERT 
TO authenticated
WITH CHECK (
    id = COALESCE(
        auth.uid()::text,
        current_setting('request.jwt.claims', true)::json->>'sub'
    )
);

-- Allow users to UPDATE their own profile
CREATE POLICY "users_update_own_profile" 
ON public.profiles 
FOR UPDATE 
TO authenticated
USING (
    id = COALESCE(
        auth.uid()::text,
        current_setting('request.jwt.claims', true)::json->>'sub'
    )
)
WITH CHECK (
    id = COALESCE(
        auth.uid()::text,
        current_setting('request.jwt.claims', true)::json->>'sub'
    )
);

-- Allow users to SELECT their own profile
CREATE POLICY "users_select_own_profile" 
ON public.profiles 
FOR SELECT 
TO authenticated
USING (
    id = COALESCE(
        auth.uid()::text,
        current_setting('request.jwt.claims', true)::json->>'sub'
    )
);

-- Allow all authenticated users to view other profiles (public info like name, avatar)
CREATE POLICY "users_select_all_profiles" 
ON public.profiles 
FOR SELECT 
TO authenticated
USING (true);

-- Step 5: Verify policies were created
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Step 6: Test the JWT claim extraction
-- This should show your Firebase UID when authenticated
SELECT 
    current_setting('request.jwt.claims', true)::json->>'sub' as firebase_uid,
    auth.uid() as supabase_uid;

