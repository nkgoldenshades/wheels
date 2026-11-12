-- This script identifies and fixes customer posts that don't have post_type='request'
-- 
-- Customer posts are created by CustomerSlotRepository, which should set post_type='request'
-- But older posts might not have this field set correctly
--
-- STRATEGY: We need to identify which posts are customer requests vs provider offers
-- Unfortunately, there's no guaranteed way to distinguish them after creation
-- 
-- MANUAL APPROACH:
-- 1. Run check_post_types.sql to see the current state
-- 2. Identify customer posts by:
--    - Looking at which user created them
--    - Checking if they appear in "My Posts" but not in vehicles table
--    - Or by profile_id if you know which users are customers vs providers
--
-- 3. Then update specific posts:
-- UPDATE posts
-- SET post_type = 'request'
-- WHERE id IN ('post-id-1', 'post-id-2', 'post-id-3');

-- ALTERNATIVE: If you want to mark ALL posts by a specific user as requests:
-- UPDATE posts
-- SET post_type = 'request'
-- WHERE profile_id = 'user-id-here';

-- SAFEST: Delete all posts and let users recreate them with correct post_type
-- DELETE FROM posts WHERE is_active = true;
-- (Only do this if you're okay losing test data!)

-- For now, let's just check the current state:
SELECT 
    id,
    profile_id,
    vehicle_id,
    service_type,
    post_type,
    COALESCE(post_type, 'NOT SET') as post_type_display,
    created_at
FROM posts
WHERE is_active = true
  AND post_type IS NULL
ORDER BY created_at DESC;
