-- Check for ANY constraints or defaults that might cast to UUID

-- 1. Check column defaults
SELECT column_name, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'bookings'
  AND (column_default LIKE '%uuid%' OR column_default LIKE '%UUID%');

-- 2. Check CHECK constraints
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.bookings'::regclass
  AND contype = 'c';

-- 3. Check if there's a view or materialized view using bookings
SELECT schemaname, viewname, definition
FROM pg_views
WHERE definition LIKE '%bookings%'
  AND (definition LIKE '%::uuid%' OR definition LIKE '%::UUID%');

-- 4. Most importantly - check the ACTUAL data type one more time
SELECT 
  column_name, 
  data_type,
  udt_name,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'bookings'
ORDER BY ordinal_position;
