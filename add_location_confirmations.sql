-- ============================================================================
-- Add location_confirmations column to bookings table
-- ============================================================================
-- This stores automatic GPS confirmation when provider/customer arrive at
-- pickup and dropoff locations (separate from manual trip_media photos)
-- ============================================================================

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS location_confirmations JSONB 
DEFAULT '{
  "pickup": {
    "provider": {
      "gps_lat": null,
      "gps_lng": null,
      "gps_accuracy": null,
      "confirmed_at": null,
      "is_confirmed": false
    },
    "customer": {
      "gps_lat": null,
      "gps_lng": null,
      "gps_accuracy": null,
      "confirmed_at": null,
      "is_confirmed": false
    }
  },
  "dropoff": {
    "provider": {
      "gps_lat": null,
      "gps_lng": null,
      "gps_accuracy": null,
      "confirmed_at": null,
      "is_confirmed": false
    },
    "customer": {
      "gps_lat": null,
      "gps_lng": null,
      "gps_accuracy": null,
      "confirmed_at": null,
      "is_confirmed": false
    }
  }
}'::jsonb;

-- ============================================================================
-- Create index for better query performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_bookings_location_confirmations 
ON bookings USING GIN (location_confirmations);

-- ============================================================================
-- Verify the column was added
-- ============================================================================
SELECT 
  column_name, 
  data_type, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'bookings' 
  AND column_name = 'location_confirmations';

-- ============================================================================
-- Example: View location confirmations for all bookings
-- ============================================================================
-- SELECT 
--   id,
--   location_confirmations->'pickup'->'provider'->>'is_confirmed' as provider_pickup_confirmed,
--   location_confirmations->'pickup'->'customer'->>'is_confirmed' as customer_pickup_confirmed,
--   location_confirmations->'dropoff'->'provider'->>'is_confirmed' as provider_dropoff_confirmed,
--   location_confirmations->'dropoff'->'customer'->>'is_confirmed' as customer_dropoff_confirmed
-- FROM bookings
-- WHERE location_confirmations IS NOT NULL;
