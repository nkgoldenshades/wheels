-- Test Guest Access to Posts
-- Run these queries in Supabase SQL Editor to verify guest access works
-- Make sure you're NOT authenticated (use anon key or public role)

-- ============================================================================
-- 1. Test posts table access (provider posts)
-- ============================================================================

-- This should return posts WITHOUT errors
SELECT 
  id,
  profile_id,
  provider_name,
  provider_avatar,
  service_type,
  slot_type,
  from_location,
  to_location,
  price,
  is_active,
  created_at
FROM public.posts
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 10;

-- Count total active posts
SELECT COUNT(*) as total_active_posts 
FROM public.posts 
WHERE is_active = true;

-- ============================================================================
-- 2. Test user_posts table access (customer requests)
-- ============================================================================

-- This should return user posts WITHOUT errors
SELECT 
  id,
  user_id,
  customer_id,
  customer_name,
  customer_avatar,
  service_type,
  slot_type,
  from_location,
  to_location,
  budget,
  status,
  is_online,
  is_active,
  created_at
FROM public.user_posts
WHERE is_active = true 
  AND status = 'active'
  AND is_online = true
ORDER BY created_at DESC
LIMIT 10;

-- Count total active user posts
SELECT COUNT(*) as total_active_user_posts 
FROM public.user_posts 
WHERE is_active = true 
  AND status = 'active'
  AND is_online = true;

-- ============================================================================
-- 3. Verify denormalized fields are populated
-- ============================================================================

-- Check posts have provider names
SELECT 
  COUNT(*) as total_posts,
  COUNT(provider_name) as posts_with_name,
  COUNT(provider_avatar) as posts_with_avatar
FROM public.posts
WHERE is_active = true;

-- Check user_posts have customer names
SELECT 
  COUNT(*) as total_user_posts,
  COUNT(customer_name) as posts_with_name,
  COUNT(customer_avatar) as posts_with_avatar
FROM public.user_posts
WHERE is_active = true;

-- ============================================================================
-- 4. Test that NO JOIN is needed
-- ============================================================================

-- This query should work for guests (no profiles access needed)
SELECT 
  p.id,
  p.provider_name,  -- Denormalized field
  p.service_type,
  p.price,
  p.from_location,
  p.to_location
FROM public.posts p
WHERE p.is_active = true
LIMIT 5;

-- This query should also work (user posts)
SELECT 
  up.id,
  up.customer_name,  -- Denormalized field
  up.service_type,
  up.budget,
  up.from_location,
  up.to_location
FROM public.user_posts up
WHERE up.is_active = true 
  AND up.status = 'active'
LIMIT 5;

-- ============================================================================
-- 5. Verify RLS policies allow guest access
-- ============================================================================

-- Check posts policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'posts'
ORDER BY policyname;

-- Check user_posts policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'user_posts'
ORDER BY policyname;

-- ============================================================================
-- 6. Test what guests CANNOT do (should fail)
-- ============================================================================

-- Guests should NOT be able to insert posts (should fail)
-- INSERT INTO public.posts (profile_id, service_type, ...) VALUES (...);

-- Guests should NOT be able to update posts (should fail)
-- UPDATE public.posts SET price = 100 WHERE id = 'some-id';

-- Guests should NOT be able to delete posts (should fail)
-- DELETE FROM public.posts WHERE id = 'some-id';

-- ============================================================================
-- 7. Expected Results
-- ============================================================================

/*
✅ SHOULD WORK (for guests):
- SELECT from posts (active posts only)
- SELECT from user_posts (active posts only)
- See provider_name and customer_name fields
- Count posts
- Filter by service_type, location, etc.

❌ SHOULD FAIL (for guests):
- INSERT into posts or user_posts
- UPDATE posts or user_posts
- DELETE posts or user_posts
- SELECT from profiles table
- Access inactive or deleted posts

🔐 SHOULD WORK (for authenticated users):
- All of the above SELECT queries
- INSERT their own posts
- UPDATE their own posts
- DELETE their own posts
- Cannot modify other users' posts
*/
