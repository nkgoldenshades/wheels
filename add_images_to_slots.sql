-- ============================================================================
-- MIGRATION: Add images column to slots table for post media
-- ============================================================================

-- Add images column to store post-specific media URLs
-- Separate from vehicle gallery; allows users to upload images for their slots
ALTER TABLE public.slots 
ADD COLUMN IF NOT EXISTS images text[] DEFAULT ARRAY[]::text[];

-- Create index for better performance when filtering by images
CREATE INDEX IF NOT EXISTS idx_slots_images ON public.slots USING GIN (images);

-- Add comment
COMMENT ON COLUMN public.slots.images IS 'Array of image URLs for this slot (user-uploaded post media)';

-- Verify the column was added
SELECT 
  COUNT(*) as total_slots,
  COUNT(*) FILTER (WHERE images IS NULL OR images = '{}') as slots_without_images
FROM public.slots;

-- ============================================================================
-- END MIGRATION
-- ============================================================================
