-- Complete fix for user_posts table
-- This addresses all mismatches between Dart code and SQL schema
-- Run this in your Supabase SQL Editor

-- 1. Add missing columns
ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' 
CHECK (status IN ('active', 'archived'));

ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true;

-- 2. Add user_id as an alias/computed column OR rename customer_id
-- Option A: Add user_id column and sync it with customer_id
ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS user_id TEXT;

-- Copy customer_id to user_id for existing records
UPDATE public.user_posts 
SET user_id = customer_id
WHERE user_id IS NULL;

-- Make user_id NOT NULL after populating
ALTER TABLE public.user_posts 
ALTER COLUMN user_id SET NOT NULL;

-- Add foreign key constraint
ALTER TABLE public.user_posts 
ADD CONSTRAINT user_posts_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 3. Update existing records to have default values
UPDATE public.user_posts 
SET 
  status = COALESCE(status, 'active'),
  is_online = COALESCE(is_online, true)
WHERE status IS NULL OR is_online IS NULL;

-- 4. Create trigger to keep user_id and customer_id in sync
CREATE OR REPLACE FUNCTION sync_user_customer_id()
RETURNS TRIGGER AS $$
BEGIN
  -- When inserting, ensure both fields are set
  IF TG_OP = 'INSERT' THEN
    IF NEW.user_id IS NOT NULL AND NEW.customer_id IS NULL THEN
      NEW.customer_id := NEW.user_id;
    ELSIF NEW.customer_id IS NOT NULL AND NEW.user_id IS NULL THEN
      NEW.user_id := NEW.customer_id;
    END IF;
  END IF;
  
  -- When updating, keep them in sync
  IF TG_OP = 'UPDATE' THEN
    IF NEW.user_id != OLD.user_id THEN
      NEW.customer_id := NEW.user_id;
    ELSIF NEW.customer_id != OLD.customer_id THEN
      NEW.user_id := NEW.customer_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_user_customer_id_trigger ON public.user_posts;
CREATE TRIGGER sync_user_customer_id_trigger
BEFORE INSERT OR UPDATE ON public.user_posts
FOR EACH ROW
EXECUTE FUNCTION sync_user_customer_id();

-- 5. Update RLS policies to work with both fields
DROP POLICY IF EXISTS "Users can view all active posts" ON public.user_posts;
CREATE POLICY "Users can view all active posts" ON public.user_posts
  FOR SELECT USING (
    (is_active = true OR is_active IS NULL) AND 
    (is_deleted = false OR is_deleted IS NULL) AND
    (status = 'active' OR status IS NULL)
  );

DROP POLICY IF EXISTS "Users can insert own posts" ON public.user_posts;
CREATE POLICY "Users can insert own posts" ON public.user_posts
  FOR INSERT WITH CHECK (
    user_id = auth.jwt()->>'sub' OR 
    customer_id = auth.jwt()->>'sub'
  );

DROP POLICY IF EXISTS "Users can update own posts" ON public.user_posts;
CREATE POLICY "Users can update own posts" ON public.user_posts
  FOR UPDATE USING (
    user_id = auth.jwt()->>'sub' OR 
    customer_id = auth.jwt()->>'sub'
  ) WITH CHECK (
    user_id = auth.jwt()->>'sub' OR 
    customer_id = auth.jwt()->>'sub'
  );

DROP POLICY IF EXISTS "Users can delete own posts" ON public.user_posts;
CREATE POLICY "Users can delete own posts" ON public.user_posts
  FOR DELETE USING (
    user_id = auth.jwt()->>'sub' OR 
    customer_id = auth.jwt()->>'sub'
  );

-- 6. Verify the changes
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_posts'
  AND column_name IN ('user_id', 'customer_id', 'status', 'is_online', 'is_active', 'is_deleted')
ORDER BY column_name;

-- 7. Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'user_posts'
ORDER BY policyname;

-- 8. Check sample data
SELECT 
  id, 
  user_id,
  customer_id,
  service_type, 
  status, 
  is_online, 
  is_active,
  is_deleted,
  created_at
FROM public.user_posts
ORDER BY created_at DESC
LIMIT 10;

-- 9. Test query (what the app runs)
SELECT * FROM public.user_posts 
WHERE (is_active = true OR is_active IS NULL) 
  AND (is_deleted = false OR is_deleted IS NULL)
ORDER BY created_at DESC;
