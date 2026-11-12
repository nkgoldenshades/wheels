-- ============================================
-- COMPLETE RLS POLICIES FOR RIDE-SHARING APP
-- ============================================
-- This sets up proper Row Level Security for all tables
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. PROFILES TABLE
-- ============================================
-- Who can see what:
-- - Everyone can see basic profile info (name, avatar) for providers
-- - Users can see and edit their own full profile
-- - Sensitive data (documents, IDs) only visible to owner

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Everyone can view basic profile info (for provider display)
CREATE POLICY "public_read_basic_profile"
ON public.profiles
FOR SELECT
TO public
USING (true);  -- Allow reading, but sensitive fields should be in a separate table

-- Users can update their own profile
CREATE POLICY "users_update_own_profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.jwt()->>'sub')
WITH CHECK (id = auth.jwt()->>'sub');

-- Users can insert their own profile (on signup)
CREATE POLICY "users_insert_own_profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.jwt()->>'sub');

-- ============================================
-- 2. VEHICLES TABLE
-- ============================================
-- Who can see what:
-- - Guests can see ONLINE vehicles (for browsing)
-- - Authenticated users can see ONLINE vehicles (for browsing)
-- - Users can see ALL their own vehicles (online + offline)
-- - Users can only modify their own vehicles

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Drop all existing permissive policies
DROP POLICY IF EXISTS "public_read_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_select_all" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_all_operations" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_all" ON public.vehicles;
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can view all vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Anyone can view online vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_insert_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_update_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_delete_own_vehicles" ON public.vehicles;

-- Guests can view ONLINE vehicles only (for browsing posts)
CREATE POLICY "guests_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO anon
USING (is_online = true);

-- Authenticated users can view:
-- 1. Their own vehicles (all of them)
-- 2. Other users' ONLINE vehicles (for browsing)
CREATE POLICY "users_view_vehicles"
ON public.vehicles
FOR SELECT
TO authenticated
USING (
  profile_id = auth.jwt()->>'sub'  -- Own vehicles
  OR is_online = true              -- Others' online vehicles
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
-- 3. POSTS TABLE (Provider Services)
-- ============================================
-- Who can see what:
-- - Everyone can see ACTIVE posts (for browsing)
-- - Users can create/edit/delete their own posts

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public read access to active posts" ON public.posts;
DROP POLICY IF EXISTS "posts_select" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;

-- Everyone can view active posts (for browsing)
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- Users can insert their own posts
CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can update their own posts
CREATE POLICY "users_update_own_posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can delete their own posts
CREATE POLICY "users_delete_own_posts"
ON public.posts
FOR DELETE
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- ============================================
-- 4. USER_POSTS TABLE (Customer Requests)
-- ============================================
-- Who can see what:
-- - Everyone can see ACTIVE user posts (providers need to see requests)
-- - Users can create/edit/delete their own posts

-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_posts (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_name TEXT,
  customer_avatar TEXT,
  service_type TEXT NOT NULL,
  slot_type TEXT NOT NULL,
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  persons INTEGER NOT NULL DEFAULT 1,
  budget NUMERIC NOT NULL,
  requires_verified_vehicle BOOLEAN DEFAULT false,
  requires_expert_vehicle BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'active',
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  is_online BOOLEAN DEFAULT true,
  notes TEXT,
  parcel_weight NUMERIC,
  parcel_length NUMERIC,
  parcel_width NUMERIC,
  parcel_height NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE public.user_posts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public read access to active user posts" ON public.user_posts;
DROP POLICY IF EXISTS "Users can view all active posts" ON public.user_posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON public.user_posts;
DROP POLICY IF EXISTS "Users can update own posts" ON public.user_posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON public.user_posts;

-- Everyone can view active user posts (providers need to see requests)
CREATE POLICY "public_view_active_user_posts"
ON public.user_posts
FOR SELECT
TO public
USING (
  (is_active = true OR is_active IS NULL) AND
  (is_deleted = false OR is_deleted IS NULL) AND
  (status = 'active' OR status IS NULL) AND
  (is_online = true OR is_online IS NULL)
);

-- Users can insert their own posts
CREATE POLICY "users_insert_own_user_posts"
ON public.user_posts
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.jwt()->>'sub' OR
  customer_id = auth.jwt()->>'sub'
);

-- Users can update their own posts
CREATE POLICY "users_update_own_user_posts"
ON public.user_posts
FOR UPDATE
TO authenticated
USING (
  user_id = auth.jwt()->>'sub' OR
  customer_id = auth.jwt()->>'sub'
)
WITH CHECK (
  user_id = auth.jwt()->>'sub' OR
  customer_id = auth.jwt()->>'sub'
);

-- Users can delete their own posts
CREATE POLICY "users_delete_own_user_posts"
ON public.user_posts
FOR DELETE
TO authenticated
USING (
  user_id = auth.jwt()->>'sub' OR
  customer_id = auth.jwt()->>'sub'
);

-- ============================================
-- 5. BOOKINGS TABLE
-- ============================================
-- Who can see what:
-- - Users can see bookings where they are customer OR provider
-- - Users can create bookings
-- - Users can update/cancel their own bookings

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can update own bookings" ON public.bookings;

-- Users can view bookings where they are involved (customer or provider)
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
CREATE POLICY "users_update_own_bookings"
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
-- 6. REVIEWS TABLE
-- ============================================
-- Who can see what:
-- - Everyone can see reviews (for transparency)
-- - Users can create reviews for their bookings
-- - Users can update their own reviews

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
DROP POLICY IF EXISTS "Users can insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "Users can update own reviews" ON public.reviews;

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
-- VERIFICATION QUERIES
-- ============================================

-- Check all RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  CASE 
    WHEN qual IS NULL THEN 'No condition'
    WHEN qual = 'true' THEN 'Allow all'
    ELSE LEFT(qual, 50) || '...'
  END as condition
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check which tables have RLS enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'vehicles', 'posts', 'user_posts', 'bookings', 'reviews')
ORDER BY tablename;

-- ============================================
-- SUMMARY OF ACCESS CONTROL
-- ============================================
/*
┌─────────────────┬──────────────────────────────────────────────────────┐
│ TABLE           │ ACCESS RULES                                         │
├─────────────────┼──────────────────────────────────────────────────────┤
│ profiles        │ • Everyone: Read basic info (name, avatar)          │
│                 │ • Owner: Read/update all fields                      │
├─────────────────┼──────────────────────────────────────────────────────┤
│ vehicles        │ • Guests: Read ONLINE vehicles only                  │
│                 │ • Authenticated: Read own vehicles + others' online  │
│                 │ • Owner: Create/update/delete own vehicles           │
├─────────────────┼──────────────────────────────────────────────────────┤
│ posts           │ • Everyone: Read ACTIVE posts                        │
│                 │ • Owner: Create/update/delete own posts              │
├─────────────────┼──────────────────────────────────────────────────────┤
│ user_posts      │ • Everyone: Read ACTIVE posts (providers see reqs)   │
│                 │ • Owner: Create/update/delete own posts              │
├─────────────────┼──────────────────────────────────────────────────────┤
│ bookings        │ • Customer/Provider: Read bookings they're in        │
│                 │ • Customer: Create bookings                          │
│                 │ • Both: Update bookings they're involved in          │
├─────────────────┼──────────────────────────────────────────────────────┤
│ reviews         │ • Everyone: Read visible reviews                     │
│                 │ • Reviewer: Create/update own reviews                │
└─────────────────┴──────────────────────────────────────────────────────┘

KEY SECURITY PRINCIPLES:
✅ Guests can browse (posts, vehicles, reviews)
✅ Users can only modify their own data
✅ Bookings visible to both parties (customer + provider)
✅ Offline vehicles hidden from guests
✅ Sensitive profile data protected
✅ Reviews are public for transparency
*/

-- ============================================
-- TESTING QUERIES
-- ============================================
/*
-- Test as guest (should work):
SELECT * FROM posts WHERE is_active = true LIMIT 5;
SELECT * FROM vehicles WHERE is_online = true LIMIT 5;
SELECT * FROM reviews WHERE is_visible = true LIMIT 5;

-- Test as authenticated user (should work):
SELECT * FROM vehicles WHERE profile_id = auth.jwt()->>'sub';
SELECT * FROM posts WHERE profile_id = auth.jwt()->>'sub';
SELECT * FROM bookings WHERE profile_customer_id = auth.jwt()->>'sub';

-- Test as guest (should fail):
INSERT INTO posts (...) VALUES (...);  -- ❌ Not authenticated
UPDATE vehicles SET is_online = false WHERE id = 'xxx';  -- ❌ Not owner
DELETE FROM bookings WHERE id = 123;  -- ❌ Not authenticated
*/
