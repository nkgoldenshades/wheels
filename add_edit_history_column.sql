-- Add edit history column to posts table
-- This stores all edit tracking data as JSON

ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS edit_history JSONB DEFAULT '{"totalEdits": 0, "edits": []}'::jsonb;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_edit_history ON public.posts USING GIN (edit_history);

-- Add comment for documentation
COMMENT ON COLUMN public.posts.edit_history IS 'Tracks all edits made to this post with timestamps and change details';

-- Verify the column was added
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'posts' 
  AND column_name = 'edit_history';

-- Show sample structure
SELECT 
  'Sample edit_history structure' as info,
  '{"totalEdits": 2, "edits": [{"timestamp": "2026-06-10T12:00:00Z", "changes": {"price": {"old": 100, "new": 150}}}]}' as example;
