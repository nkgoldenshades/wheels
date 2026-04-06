-- Complete inspection of Supabase vehicles table
-- Run these queries in your Supabase SQL Editor to see what's stored

-- 1. SHOW ALL VEHICLES (Complete Data)
SELECT 
    id,
    profile_id,
    vehicle_type,
    vehicle_owner,
    brand,
    model,
    registration_number,
    seating_capacity,
    vehicle_photo_url,
    array_length(gallery_images, 1) as gallery_count,
    rc_front_url,
    rc_back_url,
    insurance_number,
    insurance_expiry,
    insurance_document_url,
    is_active,
    created_at,
    updated_at
FROM vehicles 
ORDER BY created_at DESC;

-- 2. QUICK SUMMARY
SELECT 
    COUNT(*) as total_vehicles,
    COUNT(CASE WHEN vehicle_owner = 'provider' THEN 1 END) as provider_vehicles,
    COUNT(CASE WHEN vehicle_owner = 'customer' THEN 1 END) as customer_vehicles,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_vehicles,
    COUNT(CASE WHEN vehicle_photo_url IS NOT NULL THEN 1 END) as with_photos,
    COUNT(CASE WHEN rc_front_url IS NOT NULL THEN 1 END) as with_rc_documents
FROM vehicles;

-- 3. VEHICLES BY TYPE AND OWNER
SELECT 
    vehicle_type,
    vehicle_owner,
    COUNT(*) as count,
    STRING_AGG(DISTINCT brand, ', ') as brands
FROM vehicles 
GROUP BY vehicle_type, vehicle_owner
ORDER BY vehicle_type, vehicle_owner;

-- 4. RECENT ADDITIONS (Last 7 days)
SELECT 
    id,
    vehicle_type || ' (' || vehicle_owner || ')' as type_owner,
    COALESCE(brand, 'No Brand') || ' ' || COALESCE(model, 'No Model') as vehicle_name,
    registration_number,
    profile_id,
    created_at
FROM vehicles 
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- 5. LEGAL DOCUMENTS STATUS
SELECT 
    id,
    vehicle_type,
    vehicle_owner,
    CASE WHEN rc_front_url IS NOT NULL THEN '✅' ELSE '❌' END as rc_front,
    CASE WHEN rc_back_url IS NOT NULL THEN '✅' ELSE '❌' END as rc_back,
    CASE WHEN insurance_number IS NOT NULL THEN '✅' ELSE '❌' END as insurance_num,
    CASE WHEN insurance_document_url IS NOT NULL THEN '✅' ELSE '❌' END as insurance_doc,
    created_at
FROM vehicles 
ORDER BY created_at DESC;

-- 6. VEHICLES BY USER (Profile ID)
SELECT 
    profile_id,
    COUNT(*) as total_vehicles,
    COUNT(CASE WHEN vehicle_owner = 'provider' THEN 1 END) as providing,
    COUNT(CASE WHEN vehicle_owner = 'customer' THEN 1 END) as needing,
    STRING_AGG(DISTINCT vehicle_type, ', ') as vehicle_types,
    MAX(created_at) as last_added
FROM vehicles 
GROUP BY profile_id
ORDER BY total_vehicles DESC, last_added DESC;

-- 7. DATA COMPLETENESS CHECK
SELECT 
    'Field Completeness' as metric,
    'Total Records' as field,
    COUNT(*) as count,
    '100%' as percentage
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has Brand',
    COUNT(brand),
    ROUND(COUNT(brand) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has Model', 
    COUNT(model),
    ROUND(COUNT(model) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has Registration',
    COUNT(registration_number),
    ROUND(COUNT(registration_number) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has Photo',
    COUNT(vehicle_photo_url),
    ROUND(COUNT(vehicle_photo_url) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has RC Front',
    COUNT(rc_front_url),
    ROUND(COUNT(rc_front_url) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles

UNION ALL

SELECT 
    'Field Completeness',
    'Has Insurance',
    COUNT(insurance_number),
    ROUND(COUNT(insurance_number) * 100.0 / (SELECT COUNT(*) FROM vehicles), 1) || '%'
FROM vehicles;

-- 8. SAMPLE VEHICLE RECORDS (First 5)
SELECT 
    'Sample Vehicle #' || ROW_NUMBER() OVER (ORDER BY created_at DESC) as sample_num,
    id,
    vehicle_type,
    vehicle_owner,
    COALESCE(brand || ' ' || model, 'No Brand/Model') as full_name,
    registration_number,
    seating_capacity,
    created_at::date as date_added
FROM vehicles 
ORDER BY created_at DESC
LIMIT 5;