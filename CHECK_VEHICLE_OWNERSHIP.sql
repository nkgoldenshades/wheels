-- ============================================
-- CHECK VEHICLE OWNERSHIP ISSUE
-- ============================================
-- This checks if the vehicle belongs to the user
-- ============================================

-- Check the vehicle's profile_id
SELECT 
    id,
    profile_id,
    name,
    type,
    is_online
FROM public.vehicles
WHERE id = '00030e8f-cf85-4637-8e5f-fdeaef764071';

-- Check if there's a trigger preventing mismatched profile_ids
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('posts', 'vehicles')
ORDER BY event_object_table, trigger_name;

-- Check if there's a constraint
SELECT
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.posts'::regclass
ORDER BY conname;

-- Fix: Update the vehicle to belong to the correct user
-- Uncomment this line to fix:
-- UPDATE public.vehicles 
-- SET profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1' 
-- WHERE id = '00030e8f-cf85-4637-8e5f-fdeaef764071';
