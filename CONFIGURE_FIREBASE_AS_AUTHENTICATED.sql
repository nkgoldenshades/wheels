-- ============================================
-- CONFIGURE FIREBASE JWT AS AUTHENTICATED ROLE
-- ============================================
-- This makes Firebase JWT users appear as "authenticated"
-- ============================================

-- Create a function to check if Firebase JWT is present
CREATE OR REPLACE FUNCTION public.is_firebase_authenticated()
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if JWT has a 'sub' claim (Firebase UID)
  RETURN (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_firebase_authenticated() TO authenticated, anon;

-- Now update your RLS policies to check this function
-- Example for posts table:

DROP POLICY IF EXISTS "users_insert_own_posts" ON public.posts;

CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO public  -- Allow both anon and authenticated
WITH CHECK (
  -- Check if Firebase JWT is present AND profile_id matches
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Do the same for vehicles table:

DROP POLICY IF EXISTS "users_insert_own_vehicles" ON public.vehicles;

CREATE POLICY "users_insert_own_vehicles"
ON public.vehicles
FOR INSERT
TO public
WITH CHECK (
  public.is_firebase_authenticated() AND
  profile_id = (current_setting('request.jwt.claims', true)::json->>'sub')::text
);

-- Verify the function works
SELECT public.is_firebase_authenticated();
