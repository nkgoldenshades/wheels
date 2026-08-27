-- ============================================================================
-- DIAGNOSE: Find where UUID validation is happening in storage
-- ============================================================================

-- 1. Check storage.objects table structure
\d+ storage.objects

-- 2. Check for triggers on storage.objects
SELECT 
  t.tgname as trigger_name,
  t.tgtype,
  p.proname as function_name,
  p.prosrc as function_source
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgrelid = 'storage.objects'::regclass
ORDER BY t.tgname;

-- 3. Check for constraints on storage.objects
SELECT 
  constraint_name,
  constraint_type,
  column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'storage' AND table_name = 'objects'
ORDER BY constraint_name;

-- 4. Check storage.buckets to see if there's a type constraint
\d+ storage.buckets

-- 5. List ALL columns in storage.objects with their types
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'storage' AND table_name = 'objects'
ORDER BY ordinal_position;

-- 6. Check if there's a user_id column with UUID constraint
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'storage' 
  AND table_name = 'objects'
  AND (column_name = 'owner_id' OR column_name = 'user_id' OR column_name = 'owner')
ORDER BY column_name;

-- ============================================================================
-- PURPOSE: Find the source of "invalid input syntax for type uuid" error
-- The error is coming from somewhere in storage layer before RLS evaluation
-- ============================================================================
