-- Fix posts table schema to match code expectations

-- 1. Fix the edit history column name typo (if needed)
-- Your column is 'Edittimesanddetails' but you might want 'edit_history' for consistency
-- Option A: Rename existing column (recommended for consistency)
ALTER TABLE public.posts 
RENAME COLUMN "Edittimesanddetails" TO edit_history;

-- OR Option B: Keep existing column and just ensure it's JSONB type
-- ALTER TABLE public.posts 
-- ALTER COLUMN "Edittimesanddetails" TYPE jsonb USING "Edittimesanddetails"::jsonb;

-- 2. Add images column (currently missing from posts table)
-- Posts need their own images array (separate from vehicle gallery)
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS images text[] DEFAULT ARRAY[]::text[];

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_posts_images ON public.posts USING GIN (images);

-- Add comment
COMMENT ON COLUMN public.posts.images IS 'Array of image URLs specific to this post/slot';

-- 3. Ensure edit_history is JSONB type with default
ALTER TABLE public.posts 
ALTER COLUMN edit_history TYPE jsonb USING edit_history::jsonb,
ALTER COLUMN edit_history SET DEFAULT '{"totalEdits": 0, "edits": []}'::jsonb;

-- Add index for edit history
CREATE INDEX IF NOT EXISTS idx_posts_edit_history ON public.posts USING GIN (edit_history);

-- Verify changes
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'posts' 
  AND column_name IN ('edit_history', 'images', 'Edittimesanddetails')
ORDER BY column_name;

-- Show current structure
\d public.posts;
