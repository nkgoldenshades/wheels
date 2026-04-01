-- CRITICAL FIXES ONLY - Run this to fix immediate issues
-- These are required for your app to work correctly

-- =====================================================
-- FIX 1: Add otp_attempts for fraud detection
-- =====================================================
ALTER TABLE bookings 
  ADD COLUMN IF NOT EXISTS otp_attempts integer DEFAULT 0;

-- =====================================================
-- FIX 2: Update bookings.status to include all statuses
-- =====================================================
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'accepted'::text,
    'confirmed'::text,
    'rejected'::text,
    'completed'::text,
    'cancelled'::text,
    'refunded'::text,
    'fraud_suspected'::text,
    'expired'::text
  ]));

-- =====================================================
-- FIX 3: Ensure provider fields are nullable (optional)
-- =====================================================
-- Your app sometimes doesn't have provider info yet
ALTER TABLE bookings ALTER COLUMN provider_name DROP NOT NULL;
ALTER TABLE bookings ALTER COLUMN provider_phone DROP NOT NULL;

-- =====================================================
-- VERIFICATION
-- =====================================================
-- Check otp_attempts was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'bookings' 
  AND column_name = 'otp_attempts';

-- Check status constraint
SELECT constraint_name, check_clause
FROM information_schema.check_constraints
WHERE constraint_name = 'bookings_status_check';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Critical fixes applied';
  RAISE NOTICE '✅ otp_attempts column added';
  RAISE NOTICE '✅ bookings.status updated with all statuses';
  RAISE NOTICE '✅ provider fields made nullable';
END $$;
