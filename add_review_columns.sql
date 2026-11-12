-- Add trip_data JSONB column to reviews table (replaces separate columns)
-- This stores all trip-related metadata in a single column
ALTER TABLE public.reviews
ADD COLUMN trip_data jsonb DEFAULT '{}'::jsonb;

-- Add comment
COMMENT ON COLUMN public.reviews.trip_data IS 'Trip metadata in JSON format: {service_type, has_operator, trip_duration_minutes, distance_km, vehicle_type, etc.}';

-- Example trip_data structure:
-- {
--   "service_type": "passenger",
--   "has_operator": true,
--   "trip_duration_minutes": 45,
--   "distance_km": 12.5,
--   "vehicle_type": "sedan",
--   "pickup_verified": true,
--   "dropoff_verified": true
-- }
