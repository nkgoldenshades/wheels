-- ============================================
-- FIND AND DISABLE THE PROFILE_ID CHECK TRIGGER
-- ============================================
-- This trigger is blocking post creation
-- ============================================

-- Step 1: Find all triggers on posts table
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'posts'
ORDER BY trigger_name;

-- Step 2: Find the specific trigger checking profile_id
SELECT 
    proname as function_name,
    prosrc as function_code
FROM pg_proc
WHERE prosrc LIKE '%profile_id%'
  AND prosrc LIKE '%vehicles%'
  AND prosrc LIKE '%does not match%';

-- Step 3: Disable the trigger (replace TRIGGER_NAME with actual name from step 1)
-- ALTER TABLE public.posts DISABLE TRIGGER trigger_name_here;

-- Step 4: Or drop the trigger completely
-- DROP TRIGGER IF EXISTS trigger_name_here ON public.posts;

-- Step 5: Check all functions that might be doing this check
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE pg_get_functiondef(p.oid) LIKE '%Invalid posts.profile_id%'
   OR pg_get_functiondef(p.oid) LIKE '%does not match vehicles.profile_id%';
