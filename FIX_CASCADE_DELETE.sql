-- ============================================================
-- Add CASCADE DELETE for Posts and Bookings
-- Run this in your Supabase SQL Editor
-- ============================================================

-- First, check actual column names in bookings table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bookings' AND table_schema = 'public'
ORDER BY ordinal_position;

-- ── Fix bookings → posts foreign key with CASCADE ──────────

-- Drop existing constraints (try both possible names)
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_post_id_fkey;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_slot_id_fkey;

-- Add CASCADE on post_id (the column your app uses)
ALTER TABLE bookings 
ADD CONSTRAINT bookings_post_id_fkey 
FOREIGN KEY (post_id) 
REFERENCES posts(id) 
ON DELETE CASCADE;

-- ── Verify ─────────────────────────────────────────────────

SELECT 
  conname AS constraint_name,
  confdeltype AS on_delete_action   -- 'c' = CASCADE
FROM pg_constraint
WHERE conrelid = 'bookings'::regclass AND contype = 'f';

-- ✅ on_delete_action should be 'c' (CASCADE)
