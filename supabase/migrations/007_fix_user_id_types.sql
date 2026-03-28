-- Fix user_id columns to accept Firebase Auth string IDs instead of UUID

-- 1. Drop views that depend on users.id
DROP VIEW IF EXISTS public_profiles CASCADE;

-- 2. Fix users table
ALTER TABLE users ALTER COLUMN id TYPE TEXT;

-- 3. Recreate public_profiles view (if it was used)
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
  id,
  email,
  created_at,
  updated_at
FROM users;

-- Grant access to the view
GRANT SELECT ON public_profiles TO authenticated;
GRANT SELECT ON public_profiles TO anon;

-- 2. Fix vehicles table
ALTER TABLE vehicles ALTER COLUMN user_id TYPE TEXT;

-- 3. Fix posts table (if exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'posts') THEN
    ALTER TABLE posts ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE posts ALTER COLUMN provider_id TYPE TEXT;
  END IF;
END $$;

-- 4. Fix slots table
ALTER TABLE slots ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE slots ALTER COLUMN provider_id TYPE TEXT;

-- 5. Fix bookings table
ALTER TABLE bookings ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE bookings ALTER COLUMN provider_id TYPE TEXT;

-- 6. Fix user_post_acceptances table - add user_id column if missing
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_post_acceptances') THEN
    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'user_post_acceptances' AND column_name = 'user_id'
    ) THEN
      ALTER TABLE user_post_acceptances ADD COLUMN user_id TEXT;
    ELSE
      ALTER TABLE user_post_acceptances ALTER COLUMN user_id TYPE TEXT;
    END IF;
  END IF;
END $$;

-- 7. Fix any other tables with user references
DO $$ 
BEGIN
  -- Reviews table
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reviews') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'user_id') THEN
      ALTER TABLE reviews ALTER COLUMN user_id TYPE TEXT;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'provider_id') THEN
      ALTER TABLE reviews ALTER COLUMN provider_id TYPE TEXT;
    END IF;
  END IF;

  -- Events table
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'user_id') THEN
      ALTER TABLE events ALTER COLUMN user_id TYPE TEXT;
    END IF;
  END IF;
END $$;

COMMENT ON MIGRATION IS 'Convert UUID columns to TEXT to support Firebase Auth string IDs';
