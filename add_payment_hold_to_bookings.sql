-- Add payment hold fields to bookings table for wait-for-full mode

-- Add payment hold status
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS payment_hold_status TEXT 
CHECK (payment_hold_status IN ('none', 'authorized', 'captured', 'released'))
DEFAULT 'none';

-- Add authorization ID from payment gateway
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS payment_authorization_id TEXT;

-- Add hold expiry time
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS payment_hold_expires_at TIMESTAMP WITH TIME ZONE;

-- Add trip lock status (for wait-for-full)
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS trip_locked BOOLEAN DEFAULT false;

ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS trip_locked_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS current_bookings_count INTEGER DEFAULT 0;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_payment_hold ON public.bookings(payment_hold_status);
CREATE INDEX IF NOT EXISTS idx_posts_trip_locked ON public.posts(trip_locked);

-- Verify
SELECT 
  column_name, 
  data_type, 
  column_default 
FROM information_schema.columns 
WHERE table_name = 'bookings' 
  AND column_name LIKE '%payment%'
ORDER BY ordinal_position;
