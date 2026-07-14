-- Check if bookings exist in the database
SELECT 
    id,
    profile_customer_id,
    profile_provider_id,
    post_id,
    status,
    created_at,
    CASE 
        WHEN profile_customer_id IS NULL THEN '❌ No customer_id'
        ELSE '✅ Has customer_id'
    END as customer_status,
    CASE 
        WHEN profile_provider_id IS NULL THEN '❌ No provider_id'
        ELSE '✅ Has provider_id'
    END as provider_status
FROM bookings
ORDER BY created_at DESC
LIMIT 10;

-- Count bookings by status
SELECT 
    status,
    COUNT(*) as count
FROM bookings
GROUP BY status
ORDER BY count DESC;

-- Check for any bookings at all
SELECT COUNT(*) as total_bookings FROM bookings;
