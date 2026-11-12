-- 🚀 FRESH DATABASE SETUP
-- Complete schema for new Supabase project with Firebase auth
-- Run this in your new Supabase SQL Editor

-- ============================================================================
-- 1. PROFILES TABLE (Users)
-- ============================================================================
CREATE TABLE public.profiles (
  id text PRIMARY KEY,  -- Firebase UID
  full_name text,
  email text,
  phone_number text,
  profile_photo_url text,
  date_of_birth date,
  gender text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  country text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Document verification fields
  national_id_number text,
  national_id_front_url text,
  national_id_back_url text,
  national_id_detected_type text,
  national_id_verified boolean DEFAULT false,
  national_id_verified_at timestamp with time zone,
  
  tax_id_number text,
  tax_id_front_url text,
  tax_id_back_url text,
  tax_id_detected_type text,
  tax_id_verified boolean DEFAULT false,
  tax_id_verified_at timestamp with time zone,
  
  driving_license_number text,
  driving_license_front_url text,
  driving_license_back_url text,
  driving_license_verified boolean DEFAULT false,
  driving_license_verified_at timestamp with time zone,
  
  business_id_number text,
  business_id_front_url text,
  business_id_back_url text,
  business_id_detected_type text,
  business_id_verified boolean DEFAULT false,
  business_id_verified_at timestamp with time zone,
  
  -- AI verification
  ai_verified boolean DEFAULT false,
  ai_confidence_score integer,
  ai_verification_log jsonb,
  ai_last_checked_at timestamp with time zone,
  
  -- Liveness detection
  liveness_passed boolean DEFAULT false,
  liveness_score integer,
  liveness_attempts integer DEFAULT 0,
  liveness_video_url text,
  liveness_verified_at timestamp with time zone,
  
  -- Video verification
  video_verification_done boolean DEFAULT false,
  video_verification_url text,
  video_verification_score integer,
  video_verification_attempts integer DEFAULT 0,
  video_verification_log jsonb,
  video_verified_at timestamp with time zone,
  
  -- Status fields
  verified_badge boolean DEFAULT false,
  average_rating numeric DEFAULT 0,
  total_reviews integer DEFAULT 0,
  is_active boolean DEFAULT true,
  is_deleted boolean DEFAULT false,
  deleted_at timestamp with time zone,
  last_login_at timestamp with time zone,
  
  -- Business type
  business_type text NOT NULL DEFAULT 'solo' CHECK (business_type IN ('solo', 'pvt', 'llp')),
  preferred_language text DEFAULT 'en',
  
  -- Device tracking
  device_id text,
  device_model text,
  device_os text,
  device_ip text,
  device_last_login_at timestamp with time zone,
  device_current_lat numeric,
  device_current_lng numeric,
  device_last_seen_at timestamp with time zone,
  
  -- Security
  suspicious_flag boolean DEFAULT false,
  fraud_score integer,
  fraud_notes text,
  account_blocked boolean DEFAULT false,
  
  -- AI credits
  ai_credits_available integer DEFAULT 0,
  ai_credits_used integer DEFAULT 0,
  ai_last_used_at timestamp with time zone,
  ai_credit_reset_at timestamp with time zone,
  
  -- Verification workflow
  verification_step integer DEFAULT 0,
  verification_step_updated_at timestamp with time zone,
  documents_submitted boolean DEFAULT false,
  documents_submitted_at timestamp with time zone,
  documents_review_status text,
  documents_rejection_reason text,
  documents_verified_at timestamp with time zone
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (id = auth.jwt()->>'sub');

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (id = auth.jwt()->>'sub') WITH CHECK (id = auth.jwt()->>'sub');

CREATE POLICY "Users can delete own profile" ON public.profiles
  FOR DELETE USING (id = auth.jwt()->>'sub');

-- ============================================================================
-- 2. VEHICLES TABLE
-- ============================================================================
CREATE TABLE public.vehicles (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  owner_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  make text NOT NULL,
  model text NOT NULL,
  year integer NOT NULL,
  color text,
  license_plate text NOT NULL,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('car', 'motorcycle', 'truck', 'van', 'bus')),
  fuel_type text CHECK (fuel_type IN ('petrol', 'diesel', 'electric', 'hybrid')),
  transmission text CHECK (transmission IN ('manual', 'automatic')),
  seats integer DEFAULT 4,
  
  -- Verification
  is_verified boolean DEFAULT false,
  is_expert boolean DEFAULT false,
  verification_documents jsonb,
  verified_at timestamp with time zone,
  
  -- Status
  is_active boolean DEFAULT true,
  is_deleted boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for vehicles
CREATE POLICY "Users can view own vehicles" ON public.vehicles
  FOR SELECT USING (owner_id = auth.jwt()->>'sub');

CREATE POLICY "Users can insert own vehicles" ON public.vehicles
  FOR INSERT WITH CHECK (owner_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own vehicles" ON public.vehicles
  FOR UPDATE USING (owner_id = auth.jwt()->>'sub') WITH CHECK (owner_id = auth.jwt()->>'sub');

CREATE POLICY "Users can delete own vehicles" ON public.vehicles
  FOR DELETE USING (owner_id = auth.jwt()->>'sub');

-- ============================================================================
-- 3. SLOTS TABLE
-- ============================================================================
CREATE TABLE public.slots (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  provider_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_id text NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  
  -- Service details
  service_type text NOT NULL CHECK (service_type IN ('ride', 'delivery', 'rental')),
  slot_type text NOT NULL CHECK (slot_type IN ('from_to', 'from_range')),
  
  -- Location data
  from_location text,
  to_location text,
  base_location text,
  radius numeric,
  
  -- Timing
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  
  -- Capacity and pricing
  available_seats integer NOT NULL DEFAULT 1,
  total_seats integer NOT NULL DEFAULT 1,
  price_per_person numeric NOT NULL,
  
  -- Requirements
  requires_verified_vehicle boolean DEFAULT false,
  requires_expert_vehicle boolean DEFAULT false,
  
  -- Status
  is_active boolean DEFAULT true,
  is_deleted boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Additional info
  notes text,
  
  CONSTRAINT valid_seats CHECK (available_seats <= total_seats),
  CONSTRAINT valid_time_range CHECK (end_time > start_time),
  CONSTRAINT valid_location_data CHECK (
    (slot_type = 'from_to' AND from_location IS NOT NULL AND to_location IS NOT NULL) OR
    (slot_type = 'from_range' AND base_location IS NOT NULL AND radius IS NOT NULL)
  )
);

-- Enable RLS
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

-- RLS Policies for slots
CREATE POLICY "Users can view all active slots" ON public.slots
  FOR SELECT USING (is_active = true AND NOT is_deleted);

CREATE POLICY "Users can insert own slots" ON public.slots
  FOR INSERT WITH CHECK (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own slots" ON public.slots
  FOR UPDATE USING (provider_id = auth.jwt()->>'sub') WITH CHECK (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Users can delete own slots" ON public.slots
  FOR DELETE USING (provider_id = auth.jwt()->>'sub');

-- ============================================================================
-- 4. BOOKINGS TABLE
-- ============================================================================
CREATE TABLE public.bookings (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  slot_id text NOT NULL REFERENCES public.slots(id) ON DELETE CASCADE,
  customer_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Booking details
  persons integer NOT NULL DEFAULT 1,
  total_amount numeric NOT NULL,
  booking_status text NOT NULL DEFAULT 'pending' CHECK (
    booking_status IN ('pending', 'confirmed', 'cancelled', 'completed', 'no_show')
  ),
  
  -- Payment
  payment_status text DEFAULT 'pending' CHECK (
    payment_status IN ('pending', 'paid', 'failed', 'refunded')
  ),
  payment_intent_id text,
  
  -- Timestamps
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  confirmed_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  completed_at timestamp with time zone,
  
  -- Additional info
  customer_notes text,
  cancellation_reason text,
  
  CONSTRAINT positive_persons CHECK (persons > 0),
  CONSTRAINT positive_amount CHECK (total_amount > 0)
);

-- Enable RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for bookings
CREATE POLICY "Users can view own bookings as customer" ON public.bookings
  FOR SELECT USING (customer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can view own bookings as provider" ON public.bookings
  FOR SELECT USING (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Users can insert bookings as customer" ON public.bookings
  FOR INSERT WITH CHECK (customer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own bookings as customer" ON public.bookings
  FOR UPDATE USING (customer_id = auth.jwt()->>'sub') WITH CHECK (customer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own bookings as provider" ON public.bookings
  FOR UPDATE USING (provider_id = auth.jwt()->>'sub') WITH CHECK (provider_id = auth.jwt()->>'sub');

-- ============================================================================
-- 5. REVIEWS TABLE
-- ============================================================================
CREATE TABLE public.reviews (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  booking_id text NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  reviewer_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reviewee_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Review content
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  
  -- Review type
  review_type text NOT NULL CHECK (review_type IN ('customer_to_provider', 'provider_to_customer')),
  
  -- Timestamps
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Ensure one review per booking per direction
  UNIQUE(booking_id, reviewer_id, review_type)
);

-- Enable RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reviews
CREATE POLICY "Users can view reviews about them" ON public.reviews
  FOR SELECT USING (reviewee_id = auth.jwt()->>'sub');

CREATE POLICY "Users can view reviews they wrote" ON public.reviews
  FOR SELECT USING (reviewer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can insert reviews they write" ON public.reviews
  FOR INSERT WITH CHECK (reviewer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update reviews they wrote" ON public.reviews
  FOR UPDATE USING (reviewer_id = auth.jwt()->>'sub') WITH CHECK (reviewer_id = auth.jwt()->>'sub');

-- ============================================================================
-- 6. USER POSTS TABLE (Ride requests)
-- ============================================================================
CREATE TABLE public.user_posts (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Service details
  service_type text NOT NULL CHECK (service_type IN ('ride', 'delivery', 'rental')),
  slot_type text NOT NULL CHECK (slot_type IN ('from_to', 'from_range')),
  
  -- Location data
  from_location text,
  to_location text,
  base_location text,
  radius numeric,
  
  -- Timing
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  
  -- Requirements
  persons integer NOT NULL DEFAULT 1,
  budget numeric NOT NULL,
  requires_verified_vehicle boolean DEFAULT false,
  requires_expert_vehicle boolean DEFAULT false,
  
  -- Status
  is_active boolean DEFAULT true,
  is_deleted boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Additional info
  notes text,
  
  CONSTRAINT valid_time_range_posts CHECK (end_time > start_time),
  CONSTRAINT positive_persons_posts CHECK (persons > 0),
  CONSTRAINT positive_budget CHECK (budget > 0),
  CONSTRAINT valid_location_data_posts CHECK (
    (slot_type = 'from_to' AND from_location IS NOT NULL AND to_location IS NOT NULL) OR
    (slot_type = 'from_range' AND base_location IS NOT NULL AND radius IS NOT NULL)
  )
);

-- Enable RLS
ALTER TABLE public.user_posts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_posts
CREATE POLICY "Users can view all active posts" ON public.user_posts
  FOR SELECT USING (is_active = true AND NOT is_deleted);

CREATE POLICY "Users can insert own posts" ON public.user_posts
  FOR INSERT WITH CHECK (customer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can update own posts" ON public.user_posts
  FOR UPDATE USING (customer_id = auth.jwt()->>'sub') WITH CHECK (customer_id = auth.jwt()->>'sub');

CREATE POLICY "Users can delete own posts" ON public.user_posts
  FOR DELETE USING (customer_id = auth.jwt()->>'sub');
-- ============================================================================
-- 7. USER POST ACCEPTANCES TABLE (Provider responses to ride requests)
-- ============================================================================
CREATE TABLE public.user_post_acceptances (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  post_id text NOT NULL REFERENCES public.user_posts(id) ON DELETE CASCADE,
  provider_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_id text NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  
  -- Offer details
  offered_price numeric NOT NULL,
  message text,
  
  -- Status
  status text NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'accepted', 'rejected', 'withdrawn')
  ),
  
  -- Timestamps
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  
  CONSTRAINT positive_offered_price CHECK (offered_price > 0),
  -- Ensure one acceptance per provider per post
  UNIQUE(post_id, provider_id)
);

-- Enable RLS
ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_post_acceptances
CREATE POLICY "Post owners can view acceptances for their posts" ON public.user_post_acceptances
  FOR SELECT USING (
    post_id IN (SELECT id FROM public.user_posts WHERE customer_id = auth.jwt()->>'sub')
  );

CREATE POLICY "Providers can view their own acceptances" ON public.user_post_acceptances
  FOR SELECT USING (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Providers can insert their acceptances" ON public.user_post_acceptances
  FOR INSERT WITH CHECK (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Providers can update their acceptances" ON public.user_post_acceptances
  FOR UPDATE USING (provider_id = auth.jwt()->>'sub') WITH CHECK (provider_id = auth.jwt()->>'sub');

CREATE POLICY "Post owners can update acceptances for their posts" ON public.user_post_acceptances
  FOR UPDATE USING (
    post_id IN (SELECT id FROM public.user_posts WHERE customer_id = auth.jwt()->>'sub')
  ) WITH CHECK (
    post_id IN (SELECT id FROM public.user_posts WHERE customer_id = auth.jwt()->>'sub')
  );

-- ============================================================================
-- 8. INDEXES FOR PERFORMANCE
-- ============================================================================

-- Profiles indexes
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_phone ON public.profiles(phone_number);
CREATE INDEX idx_profiles_active ON public.profiles(is_active) WHERE is_active = true;

-- Vehicles indexes
CREATE INDEX idx_vehicles_owner ON public.vehicles(owner_id);
CREATE INDEX idx_vehicles_active ON public.vehicles(is_active) WHERE is_active = true;
CREATE INDEX idx_vehicles_type ON public.vehicles(vehicle_type);

-- Slots indexes
CREATE INDEX idx_slots_provider ON public.slots(provider_id);
CREATE INDEX idx_slots_vehicle ON public.slots(vehicle_id);
CREATE INDEX idx_slots_active ON public.slots(is_active) WHERE is_active = true;
CREATE INDEX idx_slots_service_type ON public.slots(service_type);
CREATE INDEX idx_slots_time_range ON public.slots(start_time, end_time);
CREATE INDEX idx_slots_location ON public.slots USING gin(to_tsvector('english', coalesce(from_location, '') || ' ' || coalesce(to_location, '') || ' ' || coalesce(base_location, '')));

-- Bookings indexes
CREATE INDEX idx_bookings_slot ON public.bookings(slot_id);
CREATE INDEX idx_bookings_customer ON public.bookings(customer_id);
CREATE INDEX idx_bookings_provider ON public.bookings(provider_id);
CREATE INDEX idx_bookings_status ON public.bookings(booking_status);
CREATE INDEX idx_bookings_created ON public.bookings(created_at);

-- Reviews indexes
CREATE INDEX idx_reviews_booking ON public.reviews(booking_id);
CREATE INDEX idx_reviews_reviewer ON public.reviews(reviewer_id);
CREATE INDEX idx_reviews_reviewee ON public.reviews(reviewee_id);
CREATE INDEX idx_reviews_rating ON public.reviews(rating);

-- User posts indexes
CREATE INDEX idx_user_posts_customer ON public.user_posts(customer_id);
CREATE INDEX idx_user_posts_active ON public.user_posts(is_active) WHERE is_active = true;
CREATE INDEX idx_user_posts_service_type ON public.user_posts(service_type);
CREATE INDEX idx_user_posts_time_range ON public.user_posts(start_time, end_time);

-- User post acceptances indexes
CREATE INDEX idx_acceptances_post ON public.user_post_acceptances(post_id);
CREATE INDEX idx_acceptances_provider ON public.user_post_acceptances(provider_id);
CREATE INDEX idx_acceptances_status ON public.user_post_acceptances(status);

-- ============================================================================
-- 9. FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to all tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_slots_updated_at BEFORE UPDATE ON public.slots
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_posts_updated_at BEFORE UPDATE ON public.user_posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_acceptances_updated_at BEFORE UPDATE ON public.user_post_acceptances
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 10. JWT TEST FUNCTION
-- ============================================================================

-- Function to test JWT claims (for debugging)
CREATE OR REPLACE FUNCTION get_jwt_claims() 
RETURNS jsonb 
LANGUAGE sql 
SECURITY DEFINER 
AS $$
  SELECT auth.jwt();
$$;

-- Grant access to test function
GRANT EXECUTE ON FUNCTION get_jwt_claims() TO authenticated;
GRANT EXECUTE ON FUNCTION get_jwt_claims() TO anon;

-- ============================================================================
-- SETUP COMPLETE! 
-- ============================================================================
-- 
-- 🎉 Your fresh database is ready!
-- 
-- Next steps:
-- 1. Update your Supabase config with new project URL/keys
-- 2. Test with: SELECT get_jwt_claims();
-- 3. Your Flutter app should work immediately with Firebase auth
-- 
-- All tables have proper RLS policies for Firebase JWT security.
-- ============================================================================