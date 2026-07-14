 -- ============================================================================
-- FIX: Allow post deletion by cascading to reviews
-- When a booking is deleted, also delete its reviews
-- ============================================================================

-- Drop existing foreign key constraint
ALTER TABLE reviews
DROP CONSTRAINT IF EXISTS reviews_booking_id_fkey;

-- Recreate with CASCADE
ALTER TABLE reviews
ADD CONSTRAINT reviews_booking_id_fkey
  FOREIGN KEY (booking_id)
  REFERENCES bookings(id)
  ON DELETE CASCADE;  -- When booking deleted, delete reviews too

-- Also check bookings → posts relationship
ALTER TABLE bookings
DROP CONSTRAINT IF EXISTS bookings_post_id_fkey;

ALTER TABLE bookings
ADD CONSTRAINT bookings_post_id_fkey
  FOREIGN KEY (post_id)
  REFERENCES posts(id)
  ON DELETE CASCADE;  -- When post deleted, delete bookings too

-- Test: This should now work
-- SELECT public.safe_delete_post('your-post-id', 'your-profile-id');
