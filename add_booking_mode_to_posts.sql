-- Add booking_mode to posts table to support different booking types

-- Add the column
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS booking_mode TEXT 
CHECK (booking_mode IN ('instant', 'wait_for_full', 'full_vehicle'))
DEFAULT 'instant';

-- Add index for filtering
CREATE INDEX IF NOT EXISTS idx_posts_booking_mode ON public.posts(booking_mode);

-- Update existing posts to have default mode
UPDATE public.posts 
SET booking_mode = 'instant' 
WHERE booking_mode IS NULL;

-- Verify
SELECT 
  id, 
  service_type, 
  booking_mode, 
  capacity,
  price,
  created_at 
FROM public.posts 
ORDER BY created_at DESC 
LIMIT 10;
