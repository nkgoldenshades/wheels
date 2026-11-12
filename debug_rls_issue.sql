-- ============================================
-- DEBUG: Check RLS and Profile Issues
-- ============================================
-- Run this to see what's wrong with post creation
-- ============================================

-- 1. Check if your profile exists
SELECT id, full_name, email, created_at 
FROM public.profiles 
WHERE id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- 2. Check current RLS policies on posts table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'posts'
ORDER BY policyname;

-- 3. Check if RLS is enabled on posts table
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'posts';

-- 4. Try to see what posts exist (if any)
SELECT id, profile_id, vehicle_id, service_type, created_at
FROM public.posts
LIMIT 5;
