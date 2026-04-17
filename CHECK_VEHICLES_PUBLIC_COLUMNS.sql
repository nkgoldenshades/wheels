-- ============================================
-- CHECK: What columns exist in vehicles_public view?
-- ============================================

-- Get all columns in vehicles_public view
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
ORDER BY ordinal_position;

-- This will show ALL columns in the view
-- Look for: user_name, full_name, or any name-related column

-- ============================================

-- Also check what the view definition looks like
SELECT pg_get_viewdef('vehicles_public', true);

-- This shows the exact SQL used to create the view
