-- ============================================
-- CHECK COORDINATES IN DATABASE
-- ============================================
-- Run this in Supabase SQL Editor to verify coordinates are being saved
-- ============================================

-- 1. Check if coordinate columns exist
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'posts' 
  AND column_name IN ('from_lat', 'from_lng', 'to_lat', 'to_lng', 'base_lat', 'base_lng')
ORDER BY column_name;

-- 2. Check posts with coordinates
SELECT 
  id,
  from_location,
  from_lat,
  from_lng,
  to_location,
  to_lat,
  to_lng,
  base_location,
  base_lat,
  base_lng,
  created_at
FROM posts 
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 10;

-- 3. Count posts with missing coordinates
SELECT 
  'Posts with from_location but no coordinates' as issue,
  COUNT(*) as count
FROM posts 
WHERE from_location IS NOT NULL 
  AND from_location != ''
  AND (from_lat IS NULL OR from_lng IS NULL)

UNION ALL

SELECT 
  'Posts with to_location but no coordinates' as issue,
  COUNT(*) as count
FROM posts 
WHERE to_location IS NOT NULL 
  AND to_location != ''
  AND (to_lat IS NULL OR to_lng IS NULL)

UNION ALL

SELECT 
  'Posts with base_location but no coordinates' as issue,
  COUNT(*) as count
FROM posts 
WHERE base_location IS NOT NULL 
  AND base_location != ''
  AND (base_lat IS NULL OR base_lng IS NULL);

-- 4. Show location format examples
SELECT 
  'Location Format Examples' as info,
  from_location as example_location,
  from_lat,
  from_lng,
  CASE 
    WHEN from_location LIKE '%|%,%|%' THEN '✅ Correct format: Name|lat,lng|keywords'
    WHEN from_location LIKE '%|%,%' THEN '✅ Correct format: Name|lat,lng'
    WHEN from_location IS NOT NULL AND from_location != '' THEN '❌ Missing coordinates in string'
    ELSE '⚠️ Empty location'
  END as format_check
FROM posts 
WHERE from_location IS NOT NULL 
  AND from_location != ''
LIMIT 5;

-- 5. Verify coordinate extraction worked
SELECT 
  'Coordinate Extraction Check' as check_type,
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE from_lat IS NOT NULL AND from_lng IS NOT NULL) as posts_with_from_coords,
  COUNT(*) FILTER (WHERE to_lat IS NOT NULL AND to_lng IS NOT NULL) as posts_with_to_coords,
  COUNT(*) FILTER (WHERE base_lat IS NOT NULL AND base_lng IS NOT NULL) as posts_with_base_coords,
  CASE 
    WHEN COUNT(*) FILTER (WHERE from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL) > 0 
    THEN '✅ Coordinates are being saved'
    ELSE '❌ No coordinates found - check Flutter code'
  END as status
FROM posts 
WHERE is_active = true;

-- 6. Show posts created after the fix (last 24 hours)
SELECT 
  'Recent Posts (Last 24h)' as info,
  id,
  from_location,
  CASE 
    WHEN from_lat IS NOT NULL AND from_lng IS NOT NULL 
    THEN CONCAT(from_lat, ',', from_lng)
    ELSE 'No coordinates'
  END as from_coords,
  to_location,
  CASE 
    WHEN to_lat IS NOT NULL AND to_lng IS NOT NULL 
    THEN CONCAT(to_lat, ',', to_lng)
    ELSE 'No coordinates'
  END as to_coords,
  base_location,
  CASE 
    WHEN base_lat IS NOT NULL AND base_lng IS NOT NULL 
    THEN CONCAT(base_lat, ',', base_lng)
    ELSE 'No coordinates'
  END as base_coords,
  created_at
FROM posts 
WHERE created_at > NOW() - INTERVAL '24 hours'
  AND is_active = true
ORDER BY created_at DESC;

-- 7. Test coordinate extraction function (if you want to add it to Supabase)
/*
CREATE OR REPLACE FUNCTION extract_coordinates(location_string TEXT)
RETURNS TABLE(lat NUMERIC, lng NUMERIC) AS $$
DECLARE
  parts TEXT[];
  coords TEXT[];
BEGIN
  IF location_string IS NULL OR location_string = '' THEN
    RETURN;
  END IF;
  
  -- Split by | to get parts
  parts := string_to_array(location_string, '|');
  
  -- Need at least 2 parts: Name|lat,lng
  IF array_length(parts, 1) < 2 THEN
    RETURN;
  END IF;
  
  -- Split coordinates by comma
  coords := string_to_array(parts[2], ',');
  
  -- Need exactly 2 coordinates
  IF array_length(coords, 1) != 2 THEN
    RETURN;
  END IF;
  
  -- Try to parse as numbers
  BEGIN
    lat := coords[1]::NUMERIC;
    lng := coords[2]::NUMERIC;
    RETURN NEXT;
  EXCEPTION WHEN OTHERS THEN
    RETURN;
  END;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 
  'Test Coordinate Extraction' as test,
  location_string,
  (extract_coordinates(location_string)).lat as extracted_lat,
  (extract_coordinates(location_string)).lng as extracted_lng
FROM (
  VALUES 
    ('Chennai Central|13.0827,80.2707|railway,station'),
    ('Bangalore City|12.9716,77.5946'),
    ('Invalid Location'),
    ('Mumbai|19.0760|missing_lng'),
    (NULL)
) AS test_data(location_string);
*/

-- 8. Summary
SELECT 
  '========== SUMMARY ==========' as summary,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'posts' AND column_name = 'from_lat'
    ) THEN '✅ Coordinate columns exist'
    ELSE '❌ Coordinate columns missing'
  END as columns_status,
  
  CASE 
    WHEN (SELECT COUNT(*) FROM posts WHERE from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL) > 0
    THEN '✅ Coordinates are being saved'
    ELSE '❌ No coordinates found'
  END as data_status,
  
  (SELECT COUNT(*) FROM posts WHERE is_active = true) as total_active_posts,
  (SELECT COUNT(*) FROM posts WHERE is_active = true AND (from_lat IS NOT NULL OR to_lat IS NOT NULL OR base_lat IS NOT NULL)) as posts_with_coordinates;

-- 9. Diagnose coordinate extraction issues
SELECT 
  '========== DIAGNOSTIC INFO ==========' as diagnostic,
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE from_location IS NOT NULL AND from_location != '') as posts_with_from_location_text,
  COUNT(*) FILTER (WHERE from_lat IS NOT NULL) as posts_with_from_lat,
  COUNT(*) FILTER (WHERE to_location IS NOT NULL AND to_location != '') as posts_with_to_location_text,
  COUNT(*) FILTER (WHERE to_lat IS NOT NULL) as posts_with_to_lat,
  COUNT(*) FILTER (WHERE base_location IS NOT NULL AND base_location != '') as posts_with_base_location_text,
  COUNT(*) FILTER (WHERE base_lat IS NOT NULL) as posts_with_base_lat,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE from_lat IS NOT NULL) / 
    NULLIF(COUNT(*) FILTER (WHERE from_location IS NOT NULL AND from_location != ''), 0), 
    1
  ) as from_extraction_success_rate,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE to_lat IS NOT NULL) / 
    NULLIF(COUNT(*) FILTER (WHERE to_location IS NOT NULL AND to_location != ''), 0), 
    1
  ) as to_extraction_success_rate,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE base_lat IS NOT NULL) / 
    NULLIF(COUNT(*) FILTER (WHERE base_location IS NOT NULL AND base_location != ''), 0), 
    1
  ) as base_extraction_success_rate
FROM posts 
WHERE is_active = true;