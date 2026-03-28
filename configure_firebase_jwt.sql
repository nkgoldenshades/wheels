-- Configure Supabase to accept Firebase JWT tokens
-- Run this in Supabase Dashboard > SQL Editor

-- Create a function to validate Firebase JWT
CREATE OR REPLACE FUNCTION auth.firebase_uid() 
RETURNS TEXT AS $$
  SELECT NULLIF(current_setting('request.jwt.claims', true)::json->>'sub', '')::text;
$$ LANGUAGE SQL STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION auth.firebase_uid() TO authenticated, anon;

-- Verify the function works
SELECT auth.firebase_uid();
