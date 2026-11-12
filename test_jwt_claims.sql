-- Test JWT Claims Function
-- Run this in Supabase SQL Editor first

-- Create function to get JWT claims
CREATE OR REPLACE FUNCTION get_jwt_claims() 
RETURNS jsonb 
LANGUAGE sql 
SECURITY DEFINER 
AS $$
  SELECT auth.jwt();
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION get_jwt_claims() TO authenticated;
GRANT EXECUTE ON FUNCTION get_jwt_claims() TO anon;
