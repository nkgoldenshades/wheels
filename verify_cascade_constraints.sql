-- ============================================================================
-- VERIFICATION: Check cascade constraints are properly configured
-- ============================================================================

-- Check reviews foreign key (should show ON DELETE CASCADE)
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  confrelid::regclass AS referenced_table,
  confdeltype AS on_delete_action
FROM pg_constraint
WHERE conname = 'reviews_booking_id_fkey';

-- confdeltype codes:
-- 'a' = NO ACTION
-- 'r' = RESTRICT
-- 'c' = CASCADE  ← We want this
-- 'n' = SET NULL
-- 'd' = SET DEFAULT

-- Check bookings foreign key (should show ON DELETE CASCADE)
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  confrelid::regclass AS referenced_table,
  confdeltype AS on_delete_action
FROM pg_constraint
WHERE conname = 'bookings_post_id_fkey';

-- Check what will be deleted for your specific post
-- Replace 'YOUR_POST_ID' with actual ID (e.g., '1780726877689')
SELECT 
  'Posts' as table_name,
  COUNT(*) as count
FROM posts
WHERE id = 'YOUR_POST_ID'

UNION ALL

SELECT 
  'Bookings' as table_name,
  COUNT(*) as count
FROM bookings
WHERE post_id = 'YOUR_POST_ID'

UNION ALL

SELECT 
  'Reviews' as table_name,
  COUNT(*) as count
FROM reviews
WHERE booking_id IN (
  SELECT id FROM bookings WHERE post_id = 'YOUR_POST_ID'
);
