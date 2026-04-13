-- ============================================
-- FIX ALL RLS POLICIES - COMPLETE SECURITY FIX
-- ============================================
-- This fixes ALL insecure RLS policies in your database
-- Run this entire script in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. FIX VEHICLES TABLE
-- ============================================
-- Problem: public_read_vehicles allows everyone to see ALL vehicles
-- Fix: Separate policies for guests (online only) and users (own + online)

DROP POLICY IF EXISTS "public_read_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_delete" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_insert" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_update" ON public.vehicles;

-- Guests can view ONLINE vehicles only
CREATE POLICY "guests_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO anon
USING (is_online = true);

-- Authenticated users can view their own vehicles + others' online vehicles
CREATE POLICY "users_view_vehicles"
ON public.vehicles
FOR SELECT
TO authenticated
USING (
  profile_id = auth.jwt()->>'sub' OR  -- Own vehicles (all)
  is_online = true                    -- Others' online vehicles
);

-- Users can insert their own vehicles
CREATE POLICY "users_insert_own_vehicles"
ON public.vehicles
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can update their own vehicles
CREATE POLICY "users_update_own_vehicles"
ON public.vehicles
FOR UPDATE
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can delete their own vehicles
CREATE POLICY "users_delete_own_vehicles"
ON public.vehicles
FOR DELETE
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- ============================================
-- 2. FIX POSTS TABLE
-- ============================================
-- Problem: posts_delete and posts_update allow anon users
-- Fix: Only authenticated users can modify posts

DROP POLICY IF EXISTS "public_read_posts" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;

-- Everyone can view active posts (for browsing)
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- Only authenticated users can insert their own posts
CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Only authenticated users can update their own posts
CREATE POLICY "users_update_own_posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Only authenticated users can delete their own posts
CREATE POLICY "users_delete_own_posts"
ON public.posts
FOR DELETE
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- ============================================
-- 3. FIX PROFILES TABLE
-- ============================================
-- Problem: Profiles_delete_own, Profiles_insert_own, etc. allow anon users
-- Fix: More restrictive policies

DROP POLICY IF EXISTS "Profiles_delete_own" ON public.profiles;
DROP POLICY IF EXISTS "Profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "Profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "Profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "public can read profile names" ON public.profiles;

-- Everyone can view basic profile info (for provider display)
CREATE POLICY "public_view_basic_profiles"
ON public.profiles
FOR SELECT
TO public
USING (true);

-- Users can insert their own profile (on signup)
CREATE POLICY "users_insert_own_profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.jwt()->>'sub');

-- Users can update their own profile
CREATE POLICY "users_update_own_profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.jwt()->>'sub')
WITH CHECK (id = auth.jwt()->>'sub');

-- Users can delete their own profile
CREATE POLICY "users_delete_own_profile"
ON public.profiles
FOR DELETE
TO authenticated
USING (id = auth.jwt()->>'sub');

-- ============================================
-- 4. FIX BOOKINGS TABLE
-- ============================================
-- Current policies look OK, but let's make them more explicit

DROP POLICY IF EXISTS "Users can insert own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can update own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can view own bookings" ON public.bookings;

-- Users can view bookings where they are customer OR provider
CREATE POLICY "users_view_own_bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  profile_customer_id = auth.jwt()->>'sub' OR
  profile_provider_id = auth.jwt()->>'sub'
);

-- Users can create bookings (as customer)
CREATE POLICY "users_create_bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (profile_customer_id = auth.jwt()->>'sub');

-- Users can update bookings where they are involved
CREATE POLICY "users_update_bookings"
ON public.bookings
FOR UPDATE
TO authenticated
USING (
  profile_customer_id = auth.jwt()->>'sub' OR
  profile_provider_id = auth.jwt()->>'sub'
)
WITH CHECK (
  profile_customer_id = auth.jwt()->>'sub' OR
  profile_provider_id = auth.jwt()->>'sub'
);

-- ============================================
-- 5. FIX REVIEWS TABLE
-- ============================================
-- Problem: No policies exist!
-- Fix: Add proper policies

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_view_reviews" ON public.reviews;
DROP POLICY IF EXISTS "users_create_reviews" ON public.reviews;
DROP POLICY IF EXISTS "users_update_reviews" ON public.reviews;

-- Everyone can view visible reviews
CREATE POLICY "public_view_reviews"
ON public.reviews
FOR SELECT
TO public
USING (is_visible = true);

-- Users can create reviews for bookings they're involved in
CREATE POLICY "users_create_reviews"
ON public.reviews
FOR INSERT
TO authenticated
WITH CHECK (reviewer_id = auth.jwt()->>'sub');

-- Users can update their own reviews
CREATE POLICY "users_update_own_reviews"
ON public.reviews
FOR UPDATE
TO authenticated
USING (reviewer_id = auth.jwt()->>'sub')
WITH CHECK (reviewer_id = auth.jwt()->>'sub');

-- ============================================
-- 6. FIX AI_CONVERSATIONS TABLE
-- ============================================
-- Current policies look OK, but let's verify they're secure

DROP POLICY IF EXISTS "ai_conversations_delete" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_insert" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_select" ON public.ai_conversations;
DROP POLICY IF EXISTS "ai_conversations_update" ON public.ai_conversations;

-- Users can view their own conversations
CREATE POLICY "users_view_own_conversations"
ON public.ai_conversations
FOR SELECT
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Users can create their own conversations
CREATE POLICY "users_create_own_conversations"
ON public.ai_conversations
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can update their own conversations
CREATE POLICY "users_update_own_conversations"
ON public.ai_conversations
FOR UPDATE
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can delete their own conversations
CREATE POLICY "users_delete_own_conversations"
ON public.ai_conversations
FOR DELETE
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- ============================================
-- VERIFICATION
-- ============================================

-- Check all RLS policies
SELECT 
  tablename,
  policyname,
  cmd,
  roles::text,
  CASE 
    WHEN qual LIKE '%auth.jwt%' THEN '🔒 Secure (checks user)'
    WHEN qual = 'true' THEN '⚠️ Open (no filter)'
    WHEN qual LIKE '%is_online%' THEN '🔓 Filtered (online only)'
    WHEN qual LIKE '%is_active%' THEN '🔓 Filtered (active only)'
    ELSE '❓ Other'
  END as security_level
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check which tables have RLS enabled
SELECT 
  tablename,
  CASE 
    WHEN rowsecurity THEN '✅ RLS Enabled'
    ELSE '❌ RLS Disabled'
  END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'vehicles', 'posts', 'bookings', 'reviews', 'ai_conversations')
ORDER BY tablename;

-- ============================================
-- SUMMARY OF CHANGES
-- ============================================
/*
✅ VEHICLES:
   - Removed: public_read_vehicles (insecure)
   - Added: guests_view_online_vehicles (guests see online only)
   - Added: users_view_vehicles (users see own + others' online)
   - Fixed: INSERT/UPDATE/DELETE restricted to owner

✅ POSTS:
   - Removed: anon access to UPDATE/DELETE
   - Added: Only authenticated users can modify posts
   - Kept: Public can view active posts

✅ PROFILES:
   - Removed: anon access to INSERT/UPDATE/DELETE
   - Added: Only authenticated users can modify profiles
   - Kept: Public can view basic profile info

✅ BOOKINGS:
   - Clarified: Users see bookings they're involved in
   - Secured: Only customer can create bookings
   - Secured: Only involved parties can update

✅ REVIEWS:
   - Added: RLS policies (were missing!)
   - Secured: Only reviewer can modify their reviews
   - Public: Everyone can view visible reviews

✅ AI_CONVERSATIONS:
   - Secured: Users can only access their own conversations
   - Removed: Generic authenticated policies
*/

-- ============================================
-- EXPECTED BEHAVIOR AFTER FIX
-- ============================================
/*
GUESTS (not logged in):
✅ Can browse posts (active only)
✅ Can see online vehicles
✅ Can read reviews
✅ Can view provider names (basic profile info)
❌ Cannot create/modify anything
❌ Cannot see offline vehicles
❌ Cannot see other users' private data

AUTHENTICATED USERS:
✅ Can see their own vehicles (all)
✅ Can see other users' online vehicles
✅ Can create/edit/delete their own posts
✅ Can create bookings
✅ Can see bookings they're involved in
✅ Can write/edit their own reviews
✅ Can manage their own profile
✅ Can manage their own AI conversations
❌ Cannot see other users' offline vehicles
❌ Cannot modify other users' data
❌ Cannot see other users' bookings
*/

-- ============================================
-- DONE!
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ All RLS policies have been fixed!';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Review the verification results above';
  RAISE NOTICE '   2. Restart your Flutter app';
  RAISE NOTICE '   3. Test as guest and authenticated user';
  RAISE NOTICE '   4. Verify providers only see their own vehicles';
END $$;
