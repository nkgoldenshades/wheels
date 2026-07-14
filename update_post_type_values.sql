-- Update post_type values to use clearer naming
-- Run this in Supabase SQL Editor to update existing posts

-- Update provider posts (currently 'offer' or NULL)
UPDATE posts 
SET post_type = 'provider_post'
WHERE post_type = 'offer' 
   OR post_type IS NULL
   OR post_type = '';

-- Update customer posts (currently 'request')
UPDATE posts 
SET post_type = 'customer_post'
WHERE post_type = 'request';

-- Verify the update
SELECT 
    post_type,
    COUNT(*) as count
FROM posts
GROUP BY post_type;

-- Expected result:
-- post_type       | count
-- ----------------+-------
-- provider_post   | X
-- customer_post   | Y
