-- Check if user_posts table exists and has data
-- Run this in your Supabase SQL Editor

-- 1. Check if table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'user_posts'
) as table_exists;

-- 2. Check table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_posts'
ORDER BY ordinal_position;

-- 3. Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_posts';

-- 4. Check if RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_posts';

-- 5. Count total records
SELECT COUNT(*) as total_posts FROM public.user_posts;

-- 6. Count active posts
SELECT COUNT(*) as active_posts 
FROM public.user_posts 
WHERE is_active = true AND is_deleted = false;

-- 7. Sample data (if any)
SELECT id, customer_id, service_type, slot_type, created_at, is_active, is_deleted
FROM public.user_posts
ORDER BY created_at DESC
LIMIT 5;

-- 8. Check if you're authenticated
SELECT auth.jwt();

-- 9. Test the SELECT policy directly
SELECT * FROM public.user_posts WHERE is_active = true AND is_deleted = false;
