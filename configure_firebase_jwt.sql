-- Configure Supabase to accept Firebase JWT tokens
-- This tells Supabase to trust Firebase's JWT signature

-- Option 1: If you want to keep using Firebase JWT (recommended)
-- You need to add Firebase's public key to Supabase
-- Go to: Supabase Dashboard > Authentication > Providers > Add Custom Provider
-- Provider: Firebase
-- JWKS URL: https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com

-- Option 2: Temporarily allow anon access for testing (NOT FOR PRODUCTION)
-- This will let you test if RLS is the issue

ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Test your app now. If it works, RLS was the issue.
-- Then re-enable with proper policies:

-- ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

