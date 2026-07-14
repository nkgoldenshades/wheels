-- Add rating fields to profiles_public table
-- Single rating per profile (not vehicle-specific)
-- Reviews are PERMANENT and stay with provider even if vehicles are deleted

ALTER TABLE public.profiles_public
  -- Provider ratings (overall, all vehicles combined)
  ADD COLUMN IF NOT EXISTS provider_rating DECIMAL(3, 2) DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS provider_total_reviews INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_total_trips INTEGER DEFAULT 0,
  -- Customer ratings (when using services)
  ADD COLUMN IF NOT EXISTS customer_rating DECIMAL(3, 2) DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS customer_total_reviews INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS customer_total_trips INTEGER DEFAULT 0;

-- Add indexes for sorting
CREATE INDEX IF NOT EXISTS idx_profiles_public_provider_rating 
ON public.profiles_public(provider_rating DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_public_customer_rating 
ON public.profiles_public(customer_rating DESC);

-- Add comments
COMMENT ON COLUMN public.profiles_public.provider_rating IS 'Permanent provider rating (stays even if vehicles deleted)';
COMMENT ON COLUMN public.profiles_public.provider_total_reviews IS 'Total reviews as provider (permanent, cannot be reset)';
COMMENT ON COLUMN public.profiles_public.provider_total_trips IS 'Total trips provided (permanent count)';

COMMENT ON COLUMN public.profiles_public.customer_rating IS 'Rating as customer (passenger/renter)';
COMMENT ON COLUMN public.profiles_public.customer_total_reviews IS 'Total reviews as customer';
COMMENT ON COLUMN public.profiles_public.customer_total_trips IS 'Total trips taken as customer';

-- Note: Vehicle-level reviews still exist in vehicles table for display,
-- but profile-level reviews are the SOURCE OF TRUTH
