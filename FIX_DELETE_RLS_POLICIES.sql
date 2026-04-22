-- ============================================================
-- Fix RLS Policies for Post Deletion
-- Run this in your Supabase SQL Editor
-- ============================================================

-- ── Check Current DELETE Policies ──────────────────────────

-- View all policies on posts table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'posts';

-- View all policies on user_posts table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'user_posts';

-- ── Fix Posts Table DELETE Policy ─────────────────────────

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Users can delete own posts" ON public.posts;

-- Create proper delete policy for posts
CREATE POLICY "Users can delete own posts"
  ON public.posts
  FOR DELETE
  USING (provider_id = (auth.jwt() ->> 'sub'));

-- ── Fix User Posts Table DELETE Policy ────────────────────

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Users can delete own user posts" ON public.user_posts;

-- Create proper delete policy for user_posts
CREATE POLICY "Users can delete own user posts"
  ON public.user_posts
  FOR DELETE
  USING (user_id = (auth.jwt() ->> 'sub'));

-- ── Verify Policies Are Active ────────────────────────────

-- Check posts table policies
SELECT 
  policyname,
  cmd as operation,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has condition'
    ELSE 'No condition'
  END as has_condition
FROM pg_policies
WHERE tablename = 'posts' AND cmd = 'DELETE';

-- Check user_posts table policies
SELECT 
  policyname,
  cmd as operation,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has condition'
    ELSE 'No condition'
  END as has_condition
FROM pg_policies
WHERE tablename = 'user_posts' AND cmd = 'DELETE';

-- ── Test Delete Permissions ───────────────────────────────

-- Test if current user can delete their own posts
-- Replace 'YOUR_POST_ID' with an actual post ID you own
-- SELECT * FROM posts WHERE id = 'YOUR_POST_ID' AND provider_id = (auth.jwt() ->> 'sub');

-- If the above returns a row, you should be able to delete it
-- DELETE FROM posts WHERE id = 'YOUR_POST_ID' AND provider_id = (auth.jwt() ->> 'sub');

-- ── Common Issues and Fixes ────────────────────────────────

-- Issue 1: RLS is not enabled
-- Fix:
-- ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.user_posts ENABLE ROW LEVEL SECURITY;

-- Issue 2: No JWT token (not authenticated)
-- Fix: Ensure user is logged in via Firebase Auth

-- Issue 3: provider_id/user_id doesn't match JWT sub
-- Fix: Check that the post actually belongs to the current user
-- SELECT provider_id, (auth.jwt() ->> 'sub') as current_user_id FROM posts WHERE id = 'YOUR_POST_ID';

-- Issue 4: Foreign key constraints preventing deletion
-- Check for dependent records:
-- SELECT * FROM bookings WHERE slot_id = 'YOUR_POST_ID';
-- You may need to delete or update dependent records first

-- ── Additional Helpful Queries ─────────────────────────────

-- Count posts by user
SELECT provider_id, COUNT(*) as post_count
FROM posts
GROUP BY provider_id
ORDER BY post_count DESC;

-- Count user_posts by user
SELECT user_id, COUNT(*) as post_count
FROM user_posts
GROUP BY user_id
ORDER BY post_count DESC;

-- Find posts with active bookings (can't be deleted)
SELECT p.id, p.provider_id, COUNT(b.id) as active_bookings
FROM posts p
LEFT JOIN bookings b ON b.slot_id = p.id AND b.status IN ('pending', 'confirmed')
GROUP BY p.id, p.provider_id
HAVING COUNT(b.id) > 0;

-- ── Success Indicators ─────────────────────────────────────

-- ✅ You should see:
-- 1. DELETE policies exist for both tables
-- 2. Policies check provider_id/user_id matches JWT sub
-- 3. RLS is enabled on both tables
-- 4. Test queries return expected results

-- ❌ If delete still fails:
-- 1. Check browser console for exact error message
-- 2. Check Supabase logs (Dashboard → Logs)
-- 3. Verify user is authenticated (check JWT token)
-- 4. Verify post belongs to current user
-- 5. Check for foreign key constraints
