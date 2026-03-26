-- =====================================================
-- COMPREHENSIVE SCHEMA UPDATE MIGRATION
-- =====================================================
-- This migration adds missing fields to existing tables and creates new tables
-- Includes RLS policies for security and indexes for performance
-- Generated: 2026-03-26

-- =====================================================
-- PART 1: ALTER EXISTING TABLES
-- =====================================================

-- -----------------------------------------------------
-- 1.1 BOOKINGS TABLE - Add missing fields
-- -----------------------------------------------------
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS security_deposit numeric,
  ADD COLUMN IF NOT EXISTS terms_snapshot jsonb,
  ADD COLUMN IF NOT EXISTS payment_held_in_escrow boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS stripe_client_secret text;

COMMENT ON COLUMN public.bookings.security_deposit IS 'Security deposit amount for lease bookings';
COMMENT ON COLUMN public.bookings.terms_snapshot IS 'Frozen snapshot of terms at booking time';
COMMENT ON COLUMN public.bookings.payment_held_in_escrow IS 'Whether payment is held in escrow';
COMMENT ON COLUMN public.bookings.stripe_client_secret IS 'Stripe client secret for payment confirmation';

-- -----------------------------------------------------
-- 1.2 SLOTS TABLE - Add missing fields
-- -----------------------------------------------------
ALTER TABLE public.slots
  ADD COLUMN IF NOT EXISTS service_type text CHECK (service_type IN ('passenger', 'parcel', 'working', 'lease')),
  ADD COLUMN IF NOT EXISTS seat_layout_owner_id uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS requires_approval boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS images text[],
  ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS pickup_option text CHECK (pickup_option IN ('doorstep', 'meetingPoint', 'flexible')),
  -- Parcel-specific fields
  ADD COLUMN IF NOT EXISTS max_weight numeric,
  ADD COLUMN IF NOT EXISTS max_length numeric,
  ADD COLUMN IF NOT EXISTS max_width numeric,
  ADD COLUMN IF NOT EXISTS max_height numeric,
  -- Lease-specific fields
  ADD COLUMN IF NOT EXISTS lease_duration text,
  ADD COLUMN IF NOT EXISTS security_deposit numeric,
  ADD COLUMN IF NOT EXISTS mileage_limit integer,
  ADD COLUMN IF NOT EXISTS fuel_policy text,
  ADD COLUMN IF NOT EXISTS insurance_included boolean,
  ADD COLUMN IF NOT EXISTS lease_terms text,
  ADD COLUMN IF NOT EXISTS with_operator boolean DEFAULT false;

COMMENT ON COLUMN public.slots.service_type IS 'Type of service: passenger, parcel, working, lease';
COMMENT ON COLUMN public.slots.seat_layout_owner_id IS 'Reference to seat layout for this slot';
COMMENT ON COLUMN public.slots.requires_approval IS 'Whether bookings require provider approval';
COMMENT ON COLUMN public.slots.notes IS 'Additional notes or instructions';
COMMENT ON COLUMN public.slots.images IS 'Array of image URLs for the slot';
COMMENT ON COLUMN public.slots.is_available IS 'Whether slot is currently available for booking';
COMMENT ON COLUMN public.slots.pickup_option IS 'Pickup mode: doorstep, meetingPoint, flexible';
COMMENT ON COLUMN public.slots.max_weight IS 'Maximum parcel weight in kg';
COMMENT ON COLUMN public.slots.max_length IS 'Maximum parcel length in cm';
COMMENT ON COLUMN public.slots.max_width IS 'Maximum parcel width in cm';
COMMENT ON COLUMN public.slots.max_height IS 'Maximum parcel height in cm';
COMMENT ON COLUMN public.slots.lease_duration IS 'Lease duration type: hourly, daily, weekly, monthly';
COMMENT ON COLUMN public.slots.security_deposit IS 'Security deposit amount for lease';
COMMENT ON COLUMN public.slots.mileage_limit IS 'Mileage limit in km per day';
COMMENT ON COLUMN public.slots.fuel_policy IS 'Fuel policy: full-to-full, included, etc.';
COMMENT ON COLUMN public.slots.insurance_included IS 'Whether insurance is included in lease';
COMMENT ON COLUMN public.slots.lease_terms IS 'Additional lease terms and conditions';
COMMENT ON COLUMN public.slots.with_operator IS 'Whether operator is included';

-- -----------------------------------------------------
-- 1.3 VEHICLES TABLE - Add missing fields
-- -----------------------------------------------------
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS profile_image text,
  ADD COLUMN IF NOT EXISTS registration_number text,
  ADD COLUMN IF NOT EXISTS gps_mode text CHECK (gps_mode IN ('deviceLive', 'externalLink', 'manual')) DEFAULT 'deviceLive',
  ADD COLUMN IF NOT EXISTS gps_external_link text,
  ADD COLUMN IF NOT EXISTS manual_lat numeric,
  ADD COLUMN IF NOT EXISTS manual_lng numeric,
  ADD COLUMN IF NOT EXISTS last_known_lat numeric,
  ADD COLUMN IF NOT EXISTS last_known_lng numeric,
  ADD COLUMN IF NOT EXISTS is_verified_toggle boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_expert_toggle boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS average_rating numeric DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS total_ratings integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_bookings integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active_posts_count integer DEFAULT 0,
  -- Document verification fields
  ADD COLUMN IF NOT EXISTS rc_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS rc_verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS rc_image text,
  ADD COLUMN IF NOT EXISTS insurance_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS insurance_verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS insurance_expiry_date timestamp with time zone,
  ADD COLUMN IF NOT EXISTS insurance_image text,
  ADD COLUMN IF NOT EXISTS dl_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS dl_verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS dl_image text,
  ADD COLUMN IF NOT EXISTS aadhaar_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS aadhaar_verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS aadhaar_image text,
  ADD COLUMN IF NOT EXISTS pan_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS pan_verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS pan_image text,
  ADD COLUMN IF NOT EXISTS video_url text,
  ADD COLUMN IF NOT EXISTS gallery_images text[],
  ADD COLUMN IF NOT EXISTS user_name text;

COMMENT ON COLUMN public.vehicles.profile_image IS 'Primary profile/thumbnail image (base64 or URL)';
COMMENT ON COLUMN public.vehicles.registration_number IS 'Vehicle registration number';
COMMENT ON COLUMN public.vehicles.gps_mode IS 'GPS tracking mode: deviceLive, externalLink, manual';
COMMENT ON COLUMN public.vehicles.gps_external_link IS 'External GPS tracking link';
COMMENT ON COLUMN public.vehicles.manual_lat IS 'Manually set latitude';
COMMENT ON COLUMN public.vehicles.manual_lng IS 'Manually set longitude';
COMMENT ON COLUMN public.vehicles.last_known_lat IS 'Last known latitude from device';
COMMENT ON COLUMN public.vehicles.last_known_lng IS 'Last known longitude from device';
COMMENT ON COLUMN public.vehicles.is_verified_toggle IS 'Admin-set verified status';
COMMENT ON COLUMN public.vehicles.is_expert_toggle IS 'Admin-set expert status';
COMMENT ON COLUMN public.vehicles.average_rating IS 'Average rating from reviews';
COMMENT ON COLUMN public.vehicles.total_ratings IS 'Total number of ratings';
COMMENT ON COLUMN public.vehicles.total_bookings IS 'Total completed bookings';
COMMENT ON COLUMN public.vehicles.active_posts_count IS 'Number of active posts';

-- -----------------------------------------------------
-- 1.4 USER_POSTS TABLE - Add missing fields
-- -----------------------------------------------------
ALTER TABLE public.user_posts
  ADD COLUMN IF NOT EXISTS requires_verified_vehicle boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS requires_expert_vehicle boolean DEFAULT false,
  -- Parcel-specific fields
  ADD COLUMN IF NOT EXISTS parcel_weight numeric,
  ADD COLUMN IF NOT EXISTS parcel_length numeric,
  ADD COLUMN IF NOT EXISTS parcel_width numeric,
  ADD COLUMN IF NOT EXISTS parcel_height numeric;

COMMENT ON COLUMN public.user_posts.requires_verified_vehicle IS 'Whether post requires verified vehicle';
COMMENT ON COLUMN public.user_posts.requires_expert_vehicle IS 'Whether post requires expert vehicle';
COMMENT ON COLUMN public.user_posts.parcel_weight IS 'Parcel weight in kg';
COMMENT ON COLUMN public.user_posts.parcel_length IS 'Parcel length in cm';
COMMENT ON COLUMN public.user_posts.parcel_width IS 'Parcel width in cm';
COMMENT ON COLUMN public.user_posts.parcel_height IS 'Parcel height in cm';

-- =====================================================
-- PART 2: CREATE NEW TABLES
-- =====================================================

-- -----------------------------------------------------
-- 2.1 SEAT_LAYOUTS TABLE
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.seat_layouts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  layout_data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.seat_layouts IS 'Seat layout configurations for vehicles';
COMMENT ON COLUMN public.seat_layouts.layout_data IS 'JSON structure containing seat arrangement and properties';

-- -----------------------------------------------------
-- 2.2 REVIEWS TABLE
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  reviewer_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reviewee_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE SET NULL,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_booking_reviewer UNIQUE (booking_id, reviewer_id)
);

COMMENT ON TABLE public.reviews IS 'User and vehicle reviews after completed bookings';
COMMENT ON COLUMN public.reviews.reviewer_id IS 'User who wrote the review';
COMMENT ON COLUMN public.reviews.reviewee_id IS 'User being reviewed (provider or customer)';
COMMENT ON COLUMN public.reviews.vehicle_id IS 'Vehicle being reviewed (optional)';

-- -----------------------------------------------------
-- 2.3 USER_POST_ACCEPTANCES TABLE (if not exists)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_post_acceptances (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id uuid NOT NULL REFERENCES public.user_posts(id) ON DELETE CASCADE,
  provider_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  slot_id uuid REFERENCES public.slots(id) ON DELETE SET NULL,
  vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE SET NULL,
  offered_price numeric NOT NULL,
  message text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_post_provider UNIQUE (post_id, provider_id)
);

COMMENT ON TABLE public.user_post_acceptances IS 'Provider responses to user posts';
COMMENT ON COLUMN public.user_post_acceptances.offered_price IS 'Price offered by provider';
COMMENT ON COLUMN public.user_post_acceptances.status IS 'Acceptance status: pending, accepted, rejected';

-- -----------------------------------------------------
-- 2.4 PROFILES TABLE (extended user information)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id text PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  bio text,
  location text,
  preferred_language text DEFAULT 'en',
  notification_preferences jsonb DEFAULT '{"email": true, "push": true, "sms": false}'::jsonb,
  privacy_settings jsonb DEFAULT '{"showPhone": true, "showEmail": false}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'Extended user profile information';

-- =====================================================
-- PART 3: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Bookings indexes
CREATE INDEX IF NOT EXISTS idx_bookings_stripe_payment_intent ON public.bookings(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_held_in_escrow ON public.bookings(payment_held_in_escrow);

-- Slots indexes
CREATE INDEX IF NOT EXISTS idx_slots_service_type ON public.slots(service_type);
CREATE INDEX IF NOT EXISTS idx_slots_seat_layout_owner_id ON public.slots(seat_layout_owner_id);
CREATE INDEX IF NOT EXISTS idx_slots_is_available ON public.slots(is_available);
CREATE INDEX IF NOT EXISTS idx_slots_start_time ON public.slots(start_time);
CREATE INDEX IF NOT EXISTS idx_slots_end_time ON public.slots(end_time);

-- Vehicles indexes
CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON public.vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_is_verified_toggle ON public.vehicles(is_verified_toggle);
CREATE INDEX IF NOT EXISTS idx_vehicles_is_expert_toggle ON public.vehicles(is_expert_toggle);
CREATE INDEX IF NOT EXISTS idx_vehicles_average_rating ON public.vehicles(average_rating DESC);

-- User posts indexes
CREATE INDEX IF NOT EXISTS idx_user_posts_requires_verified ON public.user_posts(requires_verified_vehicle);
CREATE INDEX IF NOT EXISTS idx_user_posts_requires_expert ON public.user_posts(requires_expert_vehicle);
CREATE INDEX IF NOT EXISTS idx_user_posts_status ON public.user_posts(status);
CREATE INDEX IF NOT EXISTS idx_user_posts_start_time ON public.user_posts(start_time);

-- Seat layouts indexes
CREATE INDEX IF NOT EXISTS idx_seat_layouts_user_id ON public.seat_layouts(user_id);

-- Reviews indexes
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON public.reviews(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON public.reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee_id ON public.reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_vehicle_id ON public.reviews(vehicle_id);

-- User post acceptances indexes
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_post_id ON public.user_post_acceptances(post_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_provider_id ON public.user_post_acceptances(provider_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_status ON public.user_post_acceptances(status);

-- =====================================================
-- PART 4: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- -----------------------------------------------------
-- 4.1 SEAT_LAYOUTS RLS
-- -----------------------------------------------------
ALTER TABLE public.seat_layouts ENABLE ROW LEVEL SECURITY;

-- Users can view all seat layouts
CREATE POLICY "seat_layouts_select_all" ON public.seat_layouts
  FOR SELECT USING (true);

-- Users can only insert their own seat layouts
CREATE POLICY "seat_layouts_insert_own" ON public.seat_layouts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own seat layouts
CREATE POLICY "seat_layouts_update_own" ON public.seat_layouts
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own seat layouts
CREATE POLICY "seat_layouts_delete_own" ON public.seat_layouts
  FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 4.2 REVIEWS RLS
-- -----------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Anyone can view reviews
CREATE POLICY "reviews_select_all" ON public.reviews
  FOR SELECT USING (true);

-- Users can only create reviews for their own bookings
CREATE POLICY "reviews_insert_own" ON public.reviews
  FOR INSERT WITH CHECK (
    auth.uid() = reviewer_id AND
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id
      AND (user_id = auth.uid() OR provider_id = auth.uid())
      AND status = 'completed'
    )
  );

-- Users can update their own reviews
CREATE POLICY "reviews_update_own" ON public.reviews
  FOR UPDATE USING (auth.uid() = reviewer_id);

-- Users can delete their own reviews
CREATE POLICY "reviews_delete_own" ON public.reviews
  FOR DELETE USING (auth.uid() = reviewer_id);

-- -----------------------------------------------------
-- 4.3 USER_POST_ACCEPTANCES RLS
-- -----------------------------------------------------
ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

-- Post owners and providers can view acceptances
CREATE POLICY "user_post_acceptances_select" ON public.user_post_acceptances
  FOR SELECT USING (
    auth.uid() = provider_id OR
    EXISTS (
      SELECT 1 FROM public.user_posts
      WHERE id = post_id AND user_id = auth.uid()
    )
  );

-- Providers can create acceptances for any post
CREATE POLICY "user_post_acceptances_insert" ON public.user_post_acceptances
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

-- Providers can update their own acceptances
CREATE POLICY "user_post_acceptances_update_provider" ON public.user_post_acceptances
  FOR UPDATE USING (auth.uid() = provider_id);

-- Post owners can update acceptance status (accept/reject)
CREATE POLICY "user_post_acceptances_update_owner" ON public.user_post_acceptances
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.user_posts
      WHERE id = post_id AND user_id = auth.uid()
    )
  );

-- Providers can delete their own acceptances
CREATE POLICY "user_post_acceptances_delete" ON public.user_post_acceptances
  FOR DELETE USING (auth.uid() = provider_id);

-- -----------------------------------------------------
-- 4.4 PROFILES RLS
-- -----------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can view profiles
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

-- Users can only insert their own profile
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Users can only delete their own profile
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE USING (auth.uid() = id);

-- =====================================================
-- PART 5: TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- =====================================================

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to new tables
DROP TRIGGER IF EXISTS update_seat_layouts_updated_at ON public.seat_layouts;
CREATE TRIGGER update_seat_layouts_updated_at
  BEFORE UPDATE ON public.seat_layouts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_reviews_updated_at ON public.reviews;
CREATE TRIGGER update_reviews_updated_at
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_post_acceptances_updated_at ON public.user_post_acceptances;
CREATE TRIGGER update_user_post_acceptances_updated_at
  BEFORE UPDATE ON public.user_post_acceptances
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- PART 6: GRANT PERMISSIONS
-- =====================================================

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.seat_layouts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reviews TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_post_acceptances TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;

-- Grant usage on sequences (for uuid generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- - Added 4 fields to bookings table
-- - Added 21 fields to slots table
-- - Added 28 fields to vehicles table
-- - Added 6 fields to user_posts table
-- - Created 4 new tables: seat_layouts, reviews, user_post_acceptances, profiles
-- - Added 18 performance indexes
-- - Configured RLS policies for all new tables
-- - Added updated_at triggers for new tables
-- =====================================================
