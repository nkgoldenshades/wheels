-- SQL queries to check vehicle database integration status
-- Run these in your Supabase SQL editor to verify vehicle storage

-- 1. Check if vehicles table exists and its structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
ORDER BY ordinal_position;

-- 2. Count total vehicles in database
SELECT COUNT(*) as total_vehicles FROM vehicles;

-- 3. Count vehicles by owner type (provider vs customer)
SELECT 
    vehicle_owner,
    COUNT(*) as count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM vehicles 
GROUP BY vehicle_owner;

-- 4. Check recent vehicle additions (last 24 hours)
SELECT 
    id,
    vehicle_type,
    vehicle_owner,
    brand,
    model,
    registration_number,
    profile_id,
    created_at,
    is_active
FROM vehicles 
WHERE created_at >= NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check vehicle distribution by type
SELECT 
    vehicle_type,
    vehicle_owner,
    COUNT(*) as count
FROM vehicles 
GROUP BY vehicle_type, vehicle_owner
ORDER BY vehicle_type, vehicle_owner;

-- 6. Check vehicles with legal documents
SELECT 
    COUNT(*) as total_vehicles,
    COUNT(rc_front_url) as with_rc_front,
    COUNT(rc_back_url) as with_rc_back,
    COUNT(insurance_number) as with_insurance_number,
    COUNT(insurance_document_url) as with_insurance_doc,
    ROUND(COUNT(rc_front_url) * 100.0 / COUNT(*), 2) as rc_front_percentage,
    ROUND(COUNT(insurance_number) * 100.0 / COUNT(*), 2) as insurance_percentage
FROM vehicles;

-- 7. Check active vs inactive vehicles
SELECT 
    is_active,
    vehicle_owner,
    COUNT(*) as count
FROM vehicles 
GROUP BY is_active, vehicle_owner
ORDER BY is_active DESC, vehicle_owner;

-- 8. Check vehicles by profile (user)
SELECT 
    profile_id,
    vehicle_owner,
    COUNT(*) as vehicle_count,
    STRING_AGG(vehicle_type, ', ') as vehicle_types
FROM vehicles 
GROUP BY profile_id, vehicle_owner
HAVING COUNT(*) > 0
ORDER BY vehicle_count DESC
LIMIT 10;

-- 9. Check for any data integrity issues
SELECT 
    'Missing profile_id' as issue,
    COUNT(*) as count
FROM vehicles 
WHERE profile_id IS NULL OR profile_id = ''

UNION ALL

SELECT 
    'Missing vehicle_type' as issue,
    COUNT(*) as count
FROM vehicles 
WHERE vehicle_type IS NULL OR vehicle_type = ''

UNION ALL

SELECT 
    'Invalid vehicle_owner' as issue,
    COUNT(*) as count
FROM vehicles 
WHERE vehicle_owner NOT IN ('provider', 'customer')

UNION ALL

SELECT 
    'Missing created_at' as issue,
    COUNT(*) as count
FROM vehicles 
WHERE created_at IS NULL;

-- 10. Sample of complete vehicle records
SELECT 
    id,
    profile_id,
    vehicle_type,
    vehicle_owner,
    brand,
    model,
    registration_number,
    seating_capacity,
    CASE WHEN vehicle_photo_url IS NOT NULL THEN 'Yes' ELSE 'No' END as has_photo,
    CASE WHEN rc_front_url IS NOT NULL THEN 'Yes' ELSE 'No' END as has_rc_front,
    CASE WHEN insurance_number IS NOT NULL THEN 'Yes' ELSE 'No' END as has_insurance,
    is_active,
    created_at
FROM vehicles 
ORDER BY created_at DESC
LIMIT 5;