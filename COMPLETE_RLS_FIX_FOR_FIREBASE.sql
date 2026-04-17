-- ============================================
-- COMPLETE RLS FIX FOR FIREBASE JWT
-- ============================================
-- This makes all RLS policies work with Firebase JWT
-- ============================================

-- Step 1: Drop the problematic trigger
DROP FUNCTION IF EXISTS validate_posts_profile_matches_vehicle CASCADE;

-- Step 2: Create helper function to check Firebase authentication
CREATE OR REPLACE FUNCTION public.is_firebase_authenticated()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.is_firebase_authenticated() TO authenticated, anon;

-- Step 3: Fix POSTS table RLS policies
DROP POLICY IF EXISTS "public_view_active_posts" ON public.posts;
DROP POLICY IF EXISTS "users_insert_own_posts" ON public.posts;
DROP POLICY IF EXISTS "users_update_own_posts" ON public.posts;
DROP POLICY IF EXISTS "users_delete_own_posts" ON public.posts;

-- Everyone can view active posts (for browsing)
CREATE POLICY "public_view_active_posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- Firebase authenticated users can insert their own posts
CREATE POLICY "firebase_users_insert_own_posts"
ON public.posts
FOR INSERT
TO public
WITH CHECK (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Firebase authenticated users can update their own posts
CREATE POLICY "firebase_users_update_own_posts"
ON public.posts
FOR UPDATE
TO public
USING (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
)
WITH CHECK (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Firebase authenticated users can delete their own posts
CREATE POLICY "firebase_users_delete_own_posts"
ON public.posts
FOR DELETE
TO public
USING (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Step 4: Fix VEHICLES table RLS policies
DROP POLICY IF EXISTS "public_view_online_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "firebase_users_insert_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "firebase_users_update_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "firebase_users_delete_own_vehicles" ON public.vehicles;

-- Everyone can view online vehicles
CREATE POLICY "public_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO public
USING (is_online = true);

-- Firebase authenticated users can insert their own vehicles
CREATE POLICY "firebase_users_insert_vehicles"
ON public.vehicles
FOR INSERT
TO public
WITH CHECK (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Firebase authenticated users can update their own vehicles
CREATE POLICY "firebase_users_update_own_vehicles"
ON public.vehicles
FOR UPDATE
TO public
USING (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
)
WITH CHECK (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Firebase authenticated users can delete their own vehicles
CREATE POLICY "firebase_users_delete_own_vehicles"
ON public.vehicles
FOR DELETE
TO public
USING (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Step 5: Verify policies were created
SELECT tablename, policyname, cmd, roles
FROM pg_policies 
WHERE tablename IN ('posts', 'vehicles')
ORDER BY tablename, policyname;
