-- Fix slot_type constraint to match Flutter enum values
-- Run this in Supabase Dashboard > SQL Editor

-- Drop the old constraint
ALTER TABLE public.slots DROP CONSTRAINT IF EXISTS slots_slot_type_check;

-- Add new constraint with Flutter enum values
ALTER TABLE public.slots 
  ADD CONSTRAINT slots_slot_type_check 
  CHECK (slot_type IN ('fromTo', 'fromRange'));

-- Verify the constraint
SELECT pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'slots_slot_type_check';
