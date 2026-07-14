-- Check if vehicles have profile images
SELECT 
    v.id as vehicle_id,
    v.name as vehicle_name,
    v.user_id,
    v.vehicle_photo_url,
    CASE 
        WHEN v.vehicle_photo_url IS NULL THEN '❌ No image'
        WHEN v.vehicle_photo_url = '' THEN '❌ Empty string'
        ELSE '✅ Has image'
    END as image_status,
    LENGTH(v.vehicle_photo_url) as image_length
FROM vehicles v
ORDER BY v.created_at DESC
LIMIT 10;

-- Check if profiles have names
SELECT 
    p.id as profile_id,
    p.full_name,
    CASE 
        WHEN p.full_name IS NULL THEN '❌ No name'
        WHEN p.full_name = '' THEN '❌ Empty string'
        WHEN LENGTH(p.full_name) < 3 THEN '⚠️ Very short name'
        ELSE '✅ Has name'
    END as name_status,
    LENGTH(p.full_name) as name_length
FROM profiles_public p
ORDER BY p.created_at DESC
LIMIT 10;

-- Check posts and their associated vehicles/profiles
SELECT 
    posts.id as post_id,
    posts.service_type,
    posts.profile_id,
    profiles_public.full_name as provider_name,
    posts.vehicle_id,
    vehicles.name as vehicle_name,
    vehicles.vehicle_photo_url,
    CASE 
        WHEN vehicles.vehicle_photo_url IS NULL OR vehicles.vehicle_photo_url = '' 
        THEN '❌ No vehicle image'
        ELSE '✅ Has vehicle image'
    END as vehicle_image_status,
    CASE 
        WHEN profiles_public.full_name IS NULL OR profiles_public.full_name = '' 
        THEN '❌ No profile name'
        ELSE '✅ Has profile name'
    END as profile_name_status
FROM posts
LEFT JOIN profiles_public ON posts.profile_id = profiles_public.id
LEFT JOIN vehicles ON posts.vehicle_id = vehicles.id
WHERE posts.is_active = true
ORDER BY posts.created_at DESC
LIMIT 10;
