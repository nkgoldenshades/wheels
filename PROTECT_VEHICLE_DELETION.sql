-- Protect Vehicle Deletion - Prevent deleting vehicles with active posts
-- Run this in Supabase SQL Editor

-- ============================================
-- OPTION 1: Add Foreign Key Constraints (Recommended)
-- ============================================
-- This prevents deletion at database level

-- Add foreign key constraint to posts table
ALTER TABLE posts
DROP CONSTRAINT IF EXISTS posts_vehicle_id_fkey;

ALTER TABLE posts
ADD CONSTRAINT posts_vehicle_id_fkey
FOREIGN KEY (vehicle_id)
REFERENCES vehicles(id)
ON DELETE RESTRICT;  -- Prevent deletion if posts exist

-- Add foreign key constraint to user_posts table
ALTER TABLE user_posts
DROP CONSTRAINT IF EXISTS user_posts_vehicle_id_fkey;

ALTER TABLE user_posts
ADD CONSTRAINT user_posts_vehicle_id_fkey
FOREIGN KEY (vehicle_id)
REFERENCES vehicles(id)
ON DELETE RESTRICT;  -- Prevent deletion if user posts exist

-- Add foreign key constraint to bookings table (if not already exists)
ALTER TABLE bookings
DROP CONSTRAINT IF EXISTS bookings_vehicle_id_fkey;

ALTER TABLE bookings
ADD CONSTRAINT bookings_vehicle_id_fkey
FOREIGN KEY (vehicle_id)
REFERENCES vehicles(id)
ON DELETE RESTRICT;  -- Prevent deletion if bookings exist

-- ============================================
-- OPTION 2: Create Trigger Function (Extra Protection)
-- ============================================
-- This provides custom error messages

CREATE OR REPLACE FUNCTION prevent_vehicle_deletion()
RETURNS TRIGGER AS $$
DECLARE
  active_posts_count INTEGER;
  active_bookings_count INTEGER;
BEGIN
  -- Check for active posts
  SELECT COUNT(*) INTO active_posts_count
  FROM posts
  WHERE vehicle_id = OLD.id
  AND is_active = true;
  
  IF active_posts_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete vehicle: % active post(s) exist. Please delete or deactivate all posts first.', active_posts_count;
  END IF;
  
  -- Check for active user posts
  SELECT COUNT(*) INTO active_posts_count
  FROM user_posts
  WHERE vehicle_id = OLD.id
  AND is_active = true;
  
  IF active_posts_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete vehicle: % active user post(s) exist. Please delete or deactivate all posts first.', active_posts_count;
  END IF;
  
  -- Check for active bookings
  SELECT COUNT(*) INTO active_bookings_count
  FROM bookings
  WHERE vehicle_id = OLD.id
  AND status NOT IN ('rejected', 'cancelled', 'completed', 'refunded');
  
  IF active_bookings_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete vehicle: % active booking(s) exist. Please wait for bookings to complete or cancel them first.', active_bookings_count;
  END IF;
  
  -- Allow deletion if no active posts or bookings
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS check_vehicle_deletion ON vehicles;

CREATE TRIGGER check_vehicle_deletion
BEFORE DELETE ON vehicles
FOR EACH ROW
EXECUTE FUNCTION prevent_vehicle_deletion();

-- ============================================
-- Verify the constraints
-- ============================================

-- Check foreign key constraints
SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND ccu.table_name = 'vehicles'
ORDER BY tc.table_name;

-- Check trigger
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'check_vehicle_deletion';

-- ============================================
-- Test the protection (Optional)
-- ============================================

-- This should fail if vehicle has active posts:
-- DELETE FROM vehicles WHERE id = 'some_vehicle_id_with_posts';

-- Expected error:
-- ERROR: Cannot delete vehicle: X active post(s) exist. Please delete or deactivate all posts first.

COMMENT ON CONSTRAINT posts_vehicle_id_fkey ON posts IS 
'Prevents deletion of vehicles that have posts. Delete posts first.';

COMMENT ON CONSTRAINT user_posts_vehicle_id_fkey ON user_posts IS 
'Prevents deletion of vehicles that have user posts. Delete posts first.';

COMMENT ON CONSTRAINT bookings_vehicle_id_fkey ON bookings IS 
'Prevents deletion of vehicles that have bookings. Complete or cancel bookings first.';

COMMENT ON FUNCTION prevent_vehicle_deletion() IS 
'Trigger function that prevents vehicle deletion if active posts or bookings exist.';

