-- Denormalize user data into posts tables for guest access
-- This eliminates the need for JOINs to profiles table
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- 1. Add denormalized fields to POSTS table (provider posts)
-- ============================================================================

ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS provider_name TEXT,
ADD COLUMN IF NOT EXISTS provider_avatar TEXT;

-- Populate existing records from profiles
UPDATE public.posts p
SET 
  provider_name = prof.full_name,
  provider_avatar = prof.avatar_url
FROM public.profiles prof
WHERE p.profile_id = prof.id
  AND (p.provider_name IS NULL OR p.provider_avatar IS NULL);

-- Create trigger to auto-populate on INSERT/UPDATE
CREATE OR REPLACE FUNCTION sync_posts_provider_info()
RETURNS TRIGGER AS $$
BEGIN
  -- Get provider info from profiles
  SELECT full_name, avatar_url
  INTO NEW.provider_name, NEW.provider_avatar
  FROM public.profiles
  WHERE id = NEW.profile_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_posts_provider_info_trigger ON public.posts;
CREATE TRIGGER sync_posts_provider_info_trigger
BEFORE INSERT OR UPDATE OF profile_id ON public.posts
FOR EACH ROW
EXECUTE FUNCTION sync_posts_provider_info();

-- ============================================================================
-- 2. Add denormalized fields to USER_POSTS table (customer requests)
-- ============================================================================

ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS customer_avatar TEXT;

-- Also add the missing columns from previous fix
ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' 
CHECK (status IN ('active', 'archived'));

ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true;

ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS user_id TEXT;

-- Populate user_id from customer_id
UPDATE public.user_posts 
SET user_id = customer_id
WHERE user_id IS NULL;

-- Make user_id NOT NULL
ALTER TABLE public.user_posts 
ALTER COLUMN user_id SET NOT NULL;

-- Add foreign key if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_posts_user_id_fkey'
  ) THEN
    ALTER TABLE public.user_posts 
    ADD CONSTRAINT user_posts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Populate existing records from profiles
UPDATE public.user_posts up
SET 
  customer_name = prof.full_name,
  customer_avatar = prof.avatar_url
FROM public.profiles prof
WHERE up.customer_id = prof.id
  AND (up.customer_name IS NULL OR up.customer_avatar IS NULL);

-- Create trigger to auto-populate on INSERT/UPDATE
CREATE OR REPLACE FUNCTION sync_user_posts_customer_info()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync user_id and customer_id
  IF NEW.user_id IS NOT NULL AND NEW.customer_id IS NULL THEN
    NEW.customer_id := NEW.user_id;
  ELSIF NEW.customer_id IS NOT NULL AND NEW.user_id IS NULL THEN
    NEW.user_id := NEW.customer_id;
  END IF;
  
  -- Get customer info from profiles
  SELECT full_name, avatar_url
  INTO NEW.customer_name, NEW.customer_avatar
  FROM public.profiles
  WHERE id = COALESCE(NEW.customer_id, NEW.user_id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_user_posts_customer_info_trigger ON public.user_posts;
CREATE TRIGGER sync_user_posts_customer_info_trigger
BEFORE INSERT OR UPDATE OF customer_id, user_id ON public.user_posts
FOR EACH ROW
EXECUTE FUNCTION sync_user_posts_customer_info();

-- ============================================================================
-- 3. Update RLS policies to allow guest access (no JOIN needed)
-- ============================================================================

-- Posts table - Allow guests to read active posts
DROP POLICY IF EXISTS "Allow public read access to active posts" ON public.posts;
CREATE POLICY "Allow public read access to active posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND is_deleted = false);

-- User posts table - Allow guests to read active posts
DROP POLICY IF EXISTS "Users can view all active posts" ON public.user_posts;
CREATE POLICY "Allow public read access to active user posts"
ON public.user_posts
FOR SELECT
TO public
USING (
  (is_active = true OR is_active IS NULL) AND 
  (is_deleted = false OR is_deleted IS NULL) AND
  (status = 'active' OR status IS NULL) AND
  (is_online = true OR is_online IS NULL)
);

-- Keep authenticated user policies for INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "Users can insert own posts" ON public.user_posts;
CREATE POLICY "Users can insert own posts" ON public.user_posts
FOR INSERT 
TO authenticated
WITH CHECK (
  user_id = auth.jwt()->>'sub' OR 
  customer_id = auth.jwt()->>'sub'
);

DROP POLICY IF EXISTS "Users can update own posts" ON public.user_posts;
CREATE POLICY "Users can update own posts" ON public.user_posts
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

DROP POLICY IF EXISTS "Users can delete own posts" ON public.user_posts;
CREATE POLICY "Users can delete own posts" ON public.user_posts
FOR DELETE 
TO authenticated
USING (
  user_id = auth.jwt()->>'sub' OR 
  customer_id = auth.jwt()->>'sub'
);

-- ============================================================================
-- 4. Create function to refresh denormalized data (if profile changes)
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_posts_provider_info()
RETURNS TRIGGER AS $$
BEGIN
  -- Update all posts by this provider
  UPDATE public.posts
  SET 
    provider_name = NEW.full_name,
    provider_avatar = NEW.avatar_url
  WHERE profile_id = NEW.id;
  
  -- Update all user posts by this customer
  UPDATE public.user_posts
  SET 
    customer_name = NEW.full_name,
    customer_avatar = NEW.avatar_url
  WHERE customer_id = NEW.id OR user_id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS refresh_posts_on_profile_update ON public.profiles;
CREATE TRIGGER refresh_posts_on_profile_update
AFTER UPDATE OF full_name, avatar_url ON public.profiles
FOR EACH ROW
WHEN (OLD.full_name IS DISTINCT FROM NEW.full_name OR OLD.avatar_url IS DISTINCT FROM NEW.avatar_url)
EXECUTE FUNCTION refresh_posts_provider_info();

-- ============================================================================
-- 5. Verification queries
-- ============================================================================

-- Check posts table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'posts'
  AND column_name IN ('provider_name', 'provider_avatar', 'profile_id')
ORDER BY column_name;

-- Check user_posts table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_posts'
  AND column_name IN ('customer_name', 'customer_avatar', 'user_id', 'customer_id', 'status', 'is_online')
ORDER BY column_name;

-- Check RLS policies
SELECT tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename IN ('posts', 'user_posts')
ORDER BY tablename, policyname;

-- Sample posts data
SELECT 
  id, 
  profile_id, 
  provider_name, 
  provider_avatar,
  service_type,
  is_active
FROM public.posts
LIMIT 5;

-- Sample user_posts data
SELECT 
  id, 
  user_id,
  customer_id,
  customer_name,
  customer_avatar,
  service_type,
  status,
  is_online
FROM public.user_posts
LIMIT 5;

-- Test guest access (should work without auth)
SELECT COUNT(*) as total_posts FROM public.posts WHERE is_active = true;
SELECT COUNT(*) as total_user_posts FROM public.user_posts WHERE is_active = true;
