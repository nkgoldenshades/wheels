-- ============================================================================
-- COMPLETE FIX FOR POSTS NOT SHOWING
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

-- Step 1: Add denormalized fields to posts table
-- ============================================================================
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS provider_name TEXT,
ADD COLUMN IF NOT EXISTS provider_avatar TEXT,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS seat_layout_owner_id TEXT,
ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS booking_mode TEXT DEFAULT 'shared',
ADD COLUMN IF NOT EXISTS min_customer_tier TEXT;

-- Step 2: Create user_posts table if it doesn't exist
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_posts (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_name TEXT,
  customer_avatar TEXT,
  
  service_type TEXT NOT NULL CHECK (service_type IN ('passenger', 'parcel', 'working', 'lease')),
  slot_type TEXT NOT NULL CHECK (slot_type IN ('from_to', 'from_range')),
  
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
  
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  is_online BOOLEAN DEFAULT true,
  
  notes TEXT,
  
  parcel_weight NUMERIC,
  parcel_length NUMERIC,
  parcel_width NUMERIC,
  parcel_height NUMERIC,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  CONSTRAINT valid_time_range_user_posts CHECK (end_time > start_time),
  CONSTRAINT positive_persons_user_posts CHECK (persons > 0),
  CONSTRAINT positive_budget CHECK (budget > 0),
  CONSTRAINT valid_location_data_user_posts CHECK (
    (slot_type = 'from_to' AND from_location IS NOT NULL AND to_location IS NOT NULL) OR
    (slot_type = 'from_range' AND base_location IS NOT NULL AND radius IS NOT NULL)
  )
);

-- Enable RLS on user_posts
ALTER TABLE public.user_posts ENABLE ROW LEVEL SECURITY;

-- Step 3: Sync user_id with customer_id for existing records
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_posts') THEN
    UPDATE public.user_posts 
    SET user_id = customer_id
    WHERE user_id IS NULL OR user_id = '';
    
    UPDATE public.user_posts 
    SET customer_id = user_id
    WHERE customer_id IS NULL OR customer_id = '';
  END IF;
END $$;

-- Step 5: Populate existing posts with provider names
-- ============================================================================
UPDATE public.posts p
SET 
  provider_name = prof.full_name,
  provider_avatar = prof.profile_photo_url
FROM public.profiles prof
WHERE p.profile_id = prof.id
  AND (p.provider_name IS NULL OR p.provider_name = '');

-- Step 6: Populate existing user_posts with customer names
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_posts') THEN
    UPDATE public.user_posts up
    SET 
      customer_name = prof.full_name,
      customer_avatar = prof.profile_photo_url,
      status = COALESCE(up.status, 'active'),
      is_online = COALESCE(up.is_online, true)
    FROM public.profiles prof
    WHERE up.customer_id = prof.id
      AND up.customer_name IS NULL;
  END IF;
END $$;

-- Step 7: Create trigger to auto-populate provider info on posts
-- ============================================================================
CREATE OR REPLACE FUNCTION sync_posts_provider_info()
RETURNS TRIGGER AS $$
BEGIN
  SELECT full_name, profile_photo_url
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

-- Step 8: Create trigger to auto-populate customer info on user_posts
-- ============================================================================
CREATE OR REPLACE FUNCTION sync_user_posts_customer_info()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync user_id and customer_id
  IF NEW.user_id IS NOT NULL AND (NEW.customer_id IS NULL OR NEW.customer_id = '') THEN
    NEW.customer_id := NEW.user_id;
  ELSIF NEW.customer_id IS NOT NULL AND (NEW.user_id IS NULL OR NEW.user_id = '') THEN
    NEW.user_id := NEW.customer_id;
  END IF;
  
  -- Get customer info from profiles
  SELECT full_name, profile_photo_url
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

-- Step 9: Update RLS policies for guest access
-- ============================================================================

-- Posts table - Allow guests to read active posts
DROP POLICY IF EXISTS "Allow public read access to active posts" ON public.posts;
CREATE POLICY "Allow public read access to active posts"
ON public.posts
FOR SELECT
TO public
USING (is_active = true AND (is_deleted = false OR is_deleted IS NULL));

-- User posts table - Allow guests to read active posts
DROP POLICY IF EXISTS "Users can view all active posts" ON public.user_posts;
DROP POLICY IF EXISTS "Allow public read access to active user posts" ON public.user_posts;
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

-- Step 10: Create trigger to update posts when profile changes
-- ============================================================================
CREATE OR REPLACE FUNCTION refresh_posts_provider_info()
RETURNS TRIGGER AS $$
BEGIN
  -- Update all posts by this provider
  UPDATE public.posts
  SET 
    provider_name = NEW.full_name,
    provider_avatar = NEW.profile_photo_url
  WHERE profile_id = NEW.id;
  
  -- Update all user posts by this customer (if table exists)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_posts') THEN
    UPDATE public.user_posts
    SET 
      customer_name = NEW.full_name,
      customer_avatar = NEW.profile_photo_url
    WHERE customer_id = NEW.id OR user_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS refresh_posts_on_profile_update ON public.profiles;
CREATE TRIGGER refresh_posts_on_profile_update
AFTER UPDATE OF full_name, profile_photo_url ON public.profiles
FOR EACH ROW
WHEN (OLD.full_name IS DISTINCT FROM NEW.full_name OR OLD.profile_photo_url IS DISTINCT FROM NEW.profile_photo_url)
EXECUTE FUNCTION refresh_posts_provider_info();

-- ============================================================================
-- VERIFICATION - Check if everything worked
-- ============================================================================

-- Check posts columns
SELECT 
  'posts table columns' as check_name,
  COUNT(*) as columns_added
FROM information_schema.columns
WHERE table_name = 'posts' 
  AND column_name IN ('provider_name', 'provider_avatar');

-- Check user_posts columns
SELECT 
  'user_posts table columns' as check_name,
  COUNT(*) as columns_added
FROM information_schema.columns
WHERE table_name = 'user_posts' 
  AND column_name IN ('customer_name', 'customer_avatar', 'user_id', 'status', 'is_online');

-- Check if posts have provider names
SELECT 
  'posts with provider names' as check_name,
  COUNT(*) as total_posts,
  COUNT(provider_name) as posts_with_names
FROM public.posts
WHERE is_active = true;

-- Check if user_posts have customer names (if table exists)
DO $$
DECLARE
  result_text TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_posts') THEN
    SELECT 
      'user_posts with customer names: ' || COUNT(*)::text || ' total, ' || COUNT(customer_name)::text || ' with names'
    INTO result_text
    FROM public.user_posts
    WHERE is_active = true;
    
    RAISE NOTICE '%', result_text;
  ELSE
    RAISE NOTICE 'user_posts table does not exist yet';
  END IF;
END $$;

-- Sample posts data
SELECT 
  'Sample posts' as check_name,
  id, 
  provider_name, 
  service_type,
  from_location,
  to_location,
  price
FROM public.posts
WHERE is_active = true
LIMIT 3;

-- Sample user_posts data (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_posts') THEN
    RAISE NOTICE 'Sample user_posts data:';
    -- Note: Cannot return SELECT results from DO block, check table manually
  ELSE
    RAISE NOTICE 'user_posts table does not exist - will be created when first user post is made';
  END IF;
END $$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Check the verification results above';
  RAISE NOTICE '   2. Restart your Flutter app';
  RAISE NOTICE '   3. Navigate to Posts page';
  RAISE NOTICE '   4. Posts should now appear!';
END $$;
