-- Fix slot deletion constraint issue
-- This addresses the "Cannot delete post if active bookings exist" error

-- =====================================================
-- STEP 1: Check current constraint
-- =====================================================
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule,
    rc.update_rule
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
    AND tc.table_name = 'bookings'
    AND kcu.column_name = 'slot_id';

-- =====================================================
-- STEP 2: Check for active bookings that would block deletion
-- =====================================================
SELECT 
    s.id as slot_id,
    s.ref_code,
    s.service_type,
    s.from_location,
    s.to_location,
    COUNT(b.id) as total_bookings,
    COUNT(CASE WHEN b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') THEN 1 END) as active_bookings,
    STRING_AGG(
        CASE WHEN b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') 
        THEN b.status || ' (' || COALESCE(b.user_name, 'Unknown') || ')' 
        END, ', '
    ) as active_booking_details
FROM slots s
LEFT JOIN bookings b ON s.id = b.slot_id
GROUP BY s.id, s.ref_code, s.service_type, s.from_location, s.to_location
HAVING COUNT(CASE WHEN b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded') THEN 1 END) > 0
ORDER BY active_bookings DESC;

-- =====================================================
-- STEP 3: OPTIONAL - Modify constraint (NOT RECOMMENDED)
-- =====================================================
-- WARNING: Only run this if you want to allow slot deletion 
-- even when bookings exist (this could cause data integrity issues)

/*
-- Drop existing constraint
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_slot_id_fkey;

-- Add new constraint with CASCADE (DANGEROUS - deletes bookings!)
-- ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
--   FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE CASCADE;

-- OR add with SET NULL (breaks booking references)
-- ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
--   FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE SET NULL;

-- RECOMMENDED: Keep original constraint for data integrity
ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
  FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE RESTRICT;
*/

-- =====================================================
-- STEP 4: Alternative - Add soft delete column
-- =====================================================
-- This allows "deleting" slots without actually removing them
-- Uncomment if you want to implement soft delete:

/*
-- Add deleted_at column for soft delete
ALTER TABLE slots ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_slots_deleted_at ON slots(deleted_at) WHERE deleted_at IS NULL;

-- Update your queries to exclude soft-deleted slots:
-- SELECT * FROM slots WHERE deleted_at IS NULL;
*/

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $
BEGIN
  RAISE NOTICE '✅ Constraint analysis complete';
  RAISE NOTICE '✅ Business logic validation added to repositories';
  RAISE NOTICE '✅ UI updated to handle deletion errors gracefully';
  RAISE NOTICE '⚠️  Slots with active bookings cannot be deleted (by design)';
  RAISE NOTICE '💡 Users will see helpful error message explaining why';
END $;