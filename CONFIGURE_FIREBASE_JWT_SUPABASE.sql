-- ============================================
-- CONFIGURE SUPABASE TO ACCEPT FIREBASE JWT
-- ============================================
-- This makes Firebase-authenticated users appear as "authenticated" role
-- ============================================

-- Step 1: You need to configure Supabase JWT Secret
-- Go to: Supabase Dashboard → Settings → API → JWT Settings
-- 
-- You need to add Firebase's JWT verification
-- Firebase JWT issuer: https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID
-- Firebase JWT audience: YOUR_FIREBASE_PROJECT_ID

-- Step 2: Alternative - Use Supabase Auth with Firebase as provider
-- Go to: Supabase Dashboard → Authentication → Providers
-- Enable "Firebase" provider
-- Add your Firebase credentials

-- Step 3: If above doesn't work, use this workaround:
-- Create a function that validates the user exists in profiles table
-- and treat that as "authenticated"

-- Create a custom role check function
CREATE OR REPLACE FUNCTION public.is_authenticated_user()
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if there's a valid session or if user exists in profiles
  RETURN (
    auth.uid() IS NOT NULL OR
    current_setting('request.jwt.claims', true)::json->>'sub' IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update RLS policies to use this function
-- For posts table:
DROP POLICY IF EXISTS "authenticated_users_insert_posts" ON public.posts;

CREATE POLICY "authenticated_users_insert_posts"
ON public.posts
FOR INSERT
TO public
WITH CHECK (
  -- Check if user is authenticated via Firebase JWT
  current_setting('request.jwt.claims', true)::json->>'sub' = profile_id
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
);

-- For vehicles table:
DROP POLICY IF EXISTS "authenticated_users_insert_vehicles" ON public.vehicles;

CREATE POLICY "authenticated_users_insert_vehicles"
ON public.vehicles
FOR INSERT
TO public
WITH CHECK (
  -- Check if user is authenticated via Firebase JWT
  current_setting('request.jwt.claims', true)::json->>'sub' = profile_id
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = profile_id)
);

-- ============================================
-- IMPORTANT: This checks that:
-- 1. The JWT contains a 'sub' claim (Firebase UID)
-- 2. The profile_id matches the JWT sub claim
-- 3. The profile exists in the database
-- 
-- This ensures ONLY authenticated users can insert
-- ============================================
