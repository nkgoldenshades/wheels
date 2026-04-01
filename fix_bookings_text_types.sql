-- Fix bookings table user_id and provider_id to TEXT type
-- This ensures Firebase Auth UIDs (text strings) work correctly

-- Step 1: Drop foreign key constraints
ALTER TABLE public.bookings 
  DROP CONSTRAINT IF EXISTS bookings_user_id_fkey,
  DROP CONSTRAINT IF EXISTS bookings_provider_id_fkey;

-- Step 2: Change column types to TEXT
ALTER TABLE public.bookings 
  ALTER COLUMN user_id TYPE text,
  ALTER COLUMN provider_id TYPE text;

-- Step 3: Recreate foreign key constraints with TEXT type
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  ADD CONSTRAINT bookings_provider_id_fkey 
    FOREIGN KEY (provider_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Verify the changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='bookings' 
  AND column_name IN ('user_id', 'provider_id');
