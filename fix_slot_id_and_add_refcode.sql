-- Fix slots table to use text IDs and add reference code
-- Run this in Supabase Dashboard > SQL Editor

-- Change id columns to text to support timestamp IDs
ALTER TABLE public.slots ALTER COLUMN id TYPE text;
ALTER TABLE public.bookings ALTER COLUMN slot_id TYPE text;
ALTER TABLE public.user_post_acceptances ALTER COLUMN slot_id TYPE text;

-- Add a short reference code column to slots
ALTER TABLE public.slots ADD COLUMN IF NOT EXISTS ref_code text;

-- Verify changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'slots' 
AND column_name IN ('id', 'ref_code')
ORDER BY column_name;
