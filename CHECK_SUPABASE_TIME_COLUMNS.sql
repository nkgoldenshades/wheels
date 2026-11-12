-- ============================================
-- CHECK: Supabase Time Column Types
-- ============================================

-- Check posts table columns
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'posts' 
  AND column_name IN ('start_time', 'end_time', 'created_at', 'updated_at')
ORDER BY ordinal_position;

-- Check user_posts table columns
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'user_posts' 
  AND column_name IN ('start_time', 'end_time', 'created_at', 'updated_at')
ORDER BY ordinal_position;

-- Show sample data to see what's actually stored
SELECT 
  id,
  start_time,
  end_time,
  created_at
FROM posts
ORDER BY created_at DESC
LIMIT 5;

-- Expected column type: timestamptz (timestamp with timezone)
-- If it's just 'timestamp', that's the problem!