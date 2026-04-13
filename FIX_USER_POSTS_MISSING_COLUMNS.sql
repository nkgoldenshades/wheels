-- Fix user_posts table - Add missing columns
-- Run this in your Supabase SQL Editor

-- Add status column if it doesn't exist
ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' 
CHECK (status IN ('active', 'archived'));

-- Add is_online column if it doesn't exist
ALTER TABLE public.user_posts 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true;

-- Update existing records to have default values
UPDATE public.user_posts 
SET 
  status = COALESCE(status, 'active'),
  is_online = COALESCE(is_online, true)
WHERE status IS NULL OR is_online IS NULL;

-- Verify the changes
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_posts'
  AND column_name IN ('status', 'is_online')
ORDER BY column_name;

-- Check data
SELECT 
  id, 
  customer_id, 
  service_type, 
  status, 
  is_online, 
  is_active,
  created_at
FROM public.user_posts
ORDER BY created_at DESC
LIMIT 10;
