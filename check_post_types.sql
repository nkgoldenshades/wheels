-- Check post_type values in the database
SELECT 
    id,
    profile_id,
    vehicle_id,
    service_type,
    post_type,
    created_at
FROM posts
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 20;

-- Check if there are posts without post_type set
SELECT 
    COUNT(*) as total_posts,
    COUNT(CASE WHEN post_type = 'offer' THEN 1 END) as offer_posts,
    COUNT(CASE WHEN post_type = 'request' THEN 1 END) as request_posts,
    COUNT(CASE WHEN post_type IS NULL THEN 1 END) as null_post_type
FROM posts
WHERE is_active = true;
