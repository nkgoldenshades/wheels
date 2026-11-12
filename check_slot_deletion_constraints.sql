-- Check for constraints that might prevent slot deletion when bookings exist

-- 1. Check foreign key constraints between bookings and slots
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND (tc.table_name = 'bookings' OR ccu.table_name = 'slots')
    AND (kcu.column_name = 'slot_id' OR ccu.column_name = 'id');

-- 2. Check if there are any triggers on slots table
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'slots';

-- 3. Check current bookings that reference slots
SELECT 
    COUNT(*) as total_bookings,
    COUNT(CASE WHEN status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') THEN 1 END) as active_bookings
FROM bookings;

-- 4. Sample of active bookings with slot references
SELECT 
    b.id,
    b.slot_id,
    b.status,
    b.created_at
FROM bookings b
WHERE b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded')
LIMIT 5;

-- 5. Check if any slots have active bookings
SELECT 
    s.id as slot_id,
    s.ref_code,
    COUNT(b.id) as booking_count,
    COUNT(CASE WHEN b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') THEN 1 END) as active_booking_count
FROM slots s
LEFT JOIN bookings b ON s.id = b.slot_id
GROUP BY s.id, s.ref_code
HAVING COUNT(CASE WHEN b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') THEN 1 END) > 0
LIMIT 10;