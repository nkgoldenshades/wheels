-- ============================================
-- COMPLETE SUPABASE RLS POLICIES
-- ============================================
-- Run this in Supabase SQL Editor to set up all RLS policies

-- ============================================
-- 1. PROFILES TABLE
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view other profiles" ON profiles;

-- Allow users to view their own profile
CREATE POLICY "Users can view their own profile" 
ON profiles 
FOR SELECT 
USING (auth.uid() = id);

-- Allow users to view other profiles (public info for bookings)
CREATE POLICY "Users can view other profiles" 
ON profiles 
FOR SELECT 
USING (true);

-- Allow users to insert their own profile
CREATE POLICY "Users can insert their own profile" 
ON profiles 
FOR INSERT 
WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile" 
ON profiles 
FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ============================================
-- 2. VEHICLES TABLE
-- ============================================
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all vehicles" ON vehicles;
DROP POLICY IF EXISTS "Users can insert their own vehicles" ON vehicles;
DROP POLICY IF EXISTS "Users can update their own vehicles" ON vehicles;
DROP POLICY IF EXISTS "Users can delete their own vehicles" ON vehicles;

-- Allow all users to view vehicles (needed for browsing posts)
CREATE POLICY "Users can view all vehicles" 
ON vehicles 
FOR SELECT 
USING (true);

-- Allow users to insert their own vehicles
CREATE POLICY "Users can insert their own vehicles" 
ON vehicles 
FOR INSERT 
WITH CHECK (auth.uid() = profile_id);

-- Allow users to update their own vehicles
CREATE POLICY "Users can update their own vehicles" 
ON vehicles 
FOR UPDATE 
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- Allow users to delete their own vehicles
CREATE POLICY "Users can delete their own vehicles" 
ON vehicles 
FOR DELETE 
USING (auth.uid() = profile_id);

-- ============================================
-- 3. POSTS TABLE
-- ============================================
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view active posts" ON posts;
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;

-- Allow ALL users to view ALL active posts (needed for browsing/feed)
-- Users can also view their own inactive posts
CREATE POLICY "Users can view active posts" 
ON posts 
FOR SELECT 
USING (
  is_active = true 
  OR auth.uid() = profile_id
);

-- Allow users to insert their own posts
CREATE POLICY "Users can insert their own posts" 
ON posts 
FOR INSERT 
WITH CHECK (auth.uid() = profile_id);

-- Allow users to update their own posts
CREATE POLICY "Users can update their own posts" 
ON posts 
FOR UPDATE 
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- Allow users to delete their own posts
CREATE POLICY "Users can delete their own posts" 
ON posts 
FOR DELETE 
USING (auth.uid() = profile_id);

-- ============================================
-- 4. BOOKINGS TABLE
-- ============================================
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their bookings" ON bookings;
DROP POLICY IF EXISTS "Users can view their bookings" ON bookings;
DROP POLICY IF EXISTS "Users can update their bookings" ON bookings;

-- Allow users to create bookings where they are the customer
CREATE POLICY "Users can insert their bookings" 
ON bookings 
FOR INSERT 
WITH CHECK (
  auth.uid() = profile_customer_id 
  AND profile_customer_id IS NOT NULL
);

-- Allow users to view bookings where they are either customer OR provider
CREATE POLICY "Users can view their bookings" 
ON bookings 
FOR SELECT 
USING (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
);

-- Allow customers and providers to update bookings
CREATE POLICY "Users can update their bookings" 
ON bookings 
FOR UPDATE 
USING (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
)
WITH CHECK (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
);

-- ============================================
-- 5. REVIEWS TABLE
-- ============================================
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all reviews" ON reviews;
DROP POLICY IF EXISTS "Users can insert their reviews" ON reviews;
DROP POLICY IF EXISTS "Users can update their reviews" ON reviews;

-- Allow all users to view visible reviews
CREATE POLICY "Users can view all reviews" 
ON reviews 
FOR SELECT 
USING (is_visible = true);

-- Allow users to insert reviews for their bookings
CREATE POLICY "Users can insert their reviews" 
ON reviews 
FOR INSERT 
WITH CHECK (auth.uid() = reviewer_id);

-- Allow users to update their own reviews
CREATE POLICY "Users can update their reviews" 
ON reviews 
FOR UPDATE 
USING (auth.uid() = reviewer_id)
WITH CHECK (auth.uid() = reviewer_id);

-- ============================================
-- 6. AI_CONVERSATIONS TABLE
-- ============================================
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their conversations" ON ai_conversations;
DROP POLICY IF EXISTS "Users can insert their conversations" ON ai_conversations;
DROP POLICY IF EXISTS "Users can update their conversations" ON ai_conversations;

-- Allow users to view their own conversations
CREATE POLICY "Users can view their conversations" 
ON ai_conversations 
FOR SELECT 
USING (auth.uid() = profile_id);

-- Allow users to insert their own conversations
CREATE POLICY "Users can insert their conversations" 
ON ai_conversations 
FOR INSERT 
WITH CHECK (auth.uid() = profile_id);

-- Allow users to update their own conversations
CREATE POLICY "Users can update their conversations" 
ON ai_conversations 
FOR UPDATE 
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- ============================================
-- VERIFY ALL POLICIES
-- ============================================
-- Run this to see all policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check 
-- FROM pg_policies 
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
