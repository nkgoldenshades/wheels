-- Check vehicle_owner values
SELECT 
    id,
    vehicle_name,
    profile_id,
    vehicle_owner,
    CASE 
        WHEN vehicle_owner IS NULL THEN '❌ NULL (will not load!)'
        WHEN vehicle_owner = 'customer' THEN '✅ Customer vehicle'
        WHEN vehicle_owner = 'provider' THEN '⚠️ Provider vehicle'
        ELSE '❓ Unknown value'
    END as owner_status,
    created_at
FROM vehicles
ORDER BY created_at DESC
LIMIT 20;

-- Count by vehicle_owner
SELECT 
    vehicle_owner,
    COUNT(*) as count
FROM vehicles
GROUP BY vehicle_owner;

-- Fix: Set all vehicles without vehicle_owner to 'customer'
-- Uncomment this line if you want to fix them:
-- UPDATE vehicles SET vehicle_owner = 'customer' WHERE vehicle_owner IS NULL;
