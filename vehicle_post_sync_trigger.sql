-- ============================================
-- TRIGGER: Sync Vehicle Status to Posts
-- ============================================
-- When a vehicle is deactivated, automatically deactivate its posts
-- When a vehicle is activated, automatically activate its posts

-- 1. Create the trigger function
CREATE OR REPLACE FUNCTION sync_vehicle_status_to_posts()
RETURNS TRIGGER AS $$
BEGIN
  -- If vehicle is_active status changed
  IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
    -- Update all posts for this vehicle
    UPDATE posts
    SET 
      is_active = NEW.is_active,
      updated_at = NOW()
    WHERE vehicle_id = NEW.id;
    
    -- Log the change
    RAISE NOTICE 'Vehicle % is_active changed to %. Updated % posts.', 
      NEW.id, 
      NEW.is_active,
      (SELECT COUNT(*) FROM posts WHERE vehicle_id = NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create the trigger
DROP TRIGGER IF EXISTS vehicle_status_sync_trigger ON vehicles;

CREATE TRIGGER vehicle_status_sync_trigger
  AFTER UPDATE ON vehicles
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION sync_vehicle_status_to_posts();

-- 3. Test the trigger
-- Deactivate a vehicle (this should also deactivate its posts)
-- UPDATE vehicles SET is_active = false WHERE id = 'test-vehicle-id';

-- 4. Verify posts were updated
-- SELECT p.id, p.is_active, v.is_active as vehicle_active
-- FROM posts p
-- JOIN vehicles v ON p.vehicle_id = v.id
-- WHERE v.id = 'test-vehicle-id';

-- ============================================
-- INITIAL SYNC (Run once to fix existing data)
-- ============================================
-- Sync all existing posts to match their vehicle's status
UPDATE posts p
SET 
  is_active = v.is_active,
  updated_at = NOW()
FROM vehicles v
WHERE p.vehicle_id = v.id
  AND p.is_active != v.is_active;

-- Verify the sync
SELECT 
  COUNT(*) as synced_posts
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.is_active = v.is_active;

-- ============================================
-- ADDITIONAL: Prevent orphaned posts
-- ============================================
-- If a vehicle is deleted, deactivate its posts (don't delete them for history)
CREATE OR REPLACE FUNCTION deactivate_posts_on_vehicle_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts
  SET 
    is_active = false,
    updated_at = NOW()
  WHERE vehicle_id = OLD.id;
  
  RAISE NOTICE 'Vehicle % deleted. Deactivated % posts.', 
    OLD.id,
    (SELECT COUNT(*) FROM posts WHERE vehicle_id = OLD.id);
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vehicle_delete_deactivate_posts ON vehicles;

CREATE TRIGGER vehicle_delete_deactivate_posts
  BEFORE DELETE ON vehicles
  FOR EACH ROW
  EXECUTE FUNCTION deactivate_posts_on_vehicle_delete();

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if any posts have mismatched status with their vehicle
SELECT 
  p.id as post_id,
  p.is_active as post_active,
  v.id as vehicle_id,
  v.is_active as vehicle_active,
  CASE 
    WHEN p.is_active = v.is_active THEN '✅ Synced'
    ELSE '❌ Mismatch'
  END as status
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
ORDER BY status DESC, p.created_at DESC;

-- Count synced vs mismatched
SELECT 
  CASE 
    WHEN p.is_active = v.is_active THEN 'Synced'
    ELSE 'Mismatch'
  END as sync_status,
  COUNT(*) as count
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
GROUP BY sync_status;
