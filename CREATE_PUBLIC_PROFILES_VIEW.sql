-- Create a public-facing view for profiles
-- This exposes only safe, public information (name and avatar)
-- Run this in Supabase SQL Editor

-- Step 1: Create the view
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
    id,  -- Use 'id' not 'profile_id' (profiles table uses 'id' as primary key)
    full_name,
    profile_photo_url as avatar_url  -- Use correct column name from profiles table
FROM profiles;

-- Step 2: Grant SELECT permission to public (anonymous users)
GRANT SELECT ON public_profiles TO anon;
GRANT SELECT ON public_profiles TO authenticated;

-- Step 3: Create RLS policy on the view (optional, but recommended)
-- Note: Views inherit RLS from base tables, but we can add extra layer
ALTER VIEW public_profiles SET (security_barrier = true);

-- Verify the view was created
SELECT * FROM public_profiles LIMIT 5;

-- Test count
SELECT COUNT(*) as total_profiles FROM public_profiles;
