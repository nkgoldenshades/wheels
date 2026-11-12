-- Add post_type column to differentiate provider offers from customer requests
-- Run this in Supabase SQL Editor

-- Step 1: Add the column (nullable initially to avoid breaking existing data)
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS post_type TEXT;

-- Step 2: Set default value for existing posts
-- All existing posts are assumed to be provider offers
UPDATE posts 
SET post_type = 'offer' 
WHERE post_type IS NULL;

-- Step 3: Make the column non-nullable with default
ALTER TABLE posts 
ALTER COLUMN post_type SET DEFAULT 'offer',
ALTER COLUMN post_type SET NOT NULL;

-- Step 4: Add index for faster filtering
CREATE INDEX IF NOT EXISTS idx_posts_post_type ON posts(post_type);

-- Step 5: Add check constraint to ensure only valid values
ALTER TABLE posts 
ADD CONSTRAINT check_post_type 
CHECK (post_type IN ('offer', 'request'));

-- Verify the changes
SELECT post_type, COUNT(*) 
FROM posts 
GROUP BY post_type;
