-- MIGRATION: Add images column to posts table
-- Safe migration that won't break existing posts

-- Step 1: Add images column (if it doesn't exist)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'posts' 
    AND column_name = 'images'
  ) THEN
    ALTER TABLE public.posts 
    ADD COLUMN images text[] DEFAULT ARRAY[]::text[];
    
    RAISE NOTICE '✅ Added images column to posts table';
  ELSE
    RAISE NOTICE 'ℹ️ Images column already exists';
  END IF;
END $$;

-- Step 2: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_images ON public.posts USING GIN (images);

-- Step 3: Verify the column was added
SELECT 
  '✅ Migration Complete' as status,
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'posts' 
  AND column_name = 'images';

-- Step 4: Show posts that will benefit from this column
SELECT 
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE images IS NULL OR images = '{}') as posts_without_images
FROM public.posts;
